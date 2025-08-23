<#
.SYNOPSIS
  Summarize CueFixer audit results (CLIXML/CSV/JSON or piped objects).

.DESCRIPTION
  Imports audit results or accepts piped-in results and prints:
    - Grouped counts (Clean, Fixable, Unfixable, etc.)
    - Percentages of total
    - Optional samples of file paths per status
    - A list of "Fixable but with no proposed fixes" items

  Outputs structured objects (summary and optional findings) so results can be piped or exported.

.PARAMETER InputFile
  Path to a CLIXML/CSV/JSON file exported by Get-CueAudit. Extension determines import method.

.PARAMETER Results
  Pass results as objects (array) directly (ValueFromPipeline). If provided, InputFile is ignored.

.PARAMETER Sample
  Number of sample paths to show for each status. Default: 5.

.PARAMETER ShowSamples
  Switch: show sample paths output.

.PARAMETER ShowPercent
  Switch: show percentage column (default: on).

.PARAMETER ShowFixableNoProposals
  Switch: show a list of Fixable items that have no .Fixes proposed.

.PARAMETER OutFile
  Optional path to write the summary (CSV or JSON by extension). If omitted, prints to console.

.EXAMPLE
  .\tools\show-audit-summary.ps1 -InputFile C:\Temp\cue-audit-d-drive.clixml -ShowSamples -Sample 8

.EXAMPLE
  Import-Clixml C:\Temp\cue-audit-d-drive.clixml | .\tools\show-audit-summary.ps1 -ShowSamples -Sample 6
#>
[CmdletBinding(DefaultParameterSetName='File')]
param(
    [Parameter(ParameterSetName='File', Position=0)]
    [string]$InputFile,

    [Parameter(ValueFromPipeline=$true, ParameterSetName='Pipeline')]
    [object[]]$Results,

    [int]$Sample = 5,
  [switch]$ShowSamples,
    [switch]$ShowFixableNoProposals,
    [string]$OutFile
)

begin {
    function Import-ResultsFromFile {
        param([string]$Path)
        if (-not (Test-Path $Path)) { throw "Input file not found: $Path" }

        switch ([IO.Path]::GetExtension($Path).ToLower()) {
            '.clixml' { return Import-Clixml $Path }
            '.xml'   { return Import-Clixml $Path }
            '.csv'   { return Import-Csv $Path }
            '.json'  { return Get-Content $Path -Raw | ConvertFrom-Json }
            default  { throw "Unrecognized extension for $Path. Supported: .clixml, .csv, .json" }
        }
    }

    $collected = @()
}

process {
    if ($PSBoundParameters.ContainsKey('Results') -and $Results) {
        # collect pipeline or direct Results param
        $collected += $Results
    } else {
        # if pipeline provided piece-by-piece (ValueFromPipeline), process{} collects it.
    }
}

end {
    try {
        if (-not $collected -or $collected.Count -eq 0) {
            if ($InputFile) {
                Write-Verbose "Importing results from $InputFile"
                $collected = Import-ResultsFromFile -Path $InputFile
            } else {
                Write-Error "No input provided. Provide -InputFile or pipe objects to the script."
                return
            }
        }

        # Ensure array
        $results = @($collected)
        $total = $results.Count

        # defensive: make sure objects have a Status property
        $results = $results | ForEach-Object {
            if (-not $_.PSObject.Properties.Match('Status')) {
                $_ | Add-Member -NotePropertyName Status -NotePropertyValue 'Unknown' -Force -PassThru
            } else { $_ }
        }

        # Group counts
        $grouped = $results | Group-Object -Property Status

        $summary = $grouped | ForEach-Object {
            $count = $_.Count
            $pct = if ($total -gt 0) { "{0:P1}" -f ($count / $total) } else { "N/A" }
            [PSCustomObject]@{
                Status  = $_.Name
                Count   = $count
                Percent = $pct
            }
        } | Sort-Object -Property Status

  # Print a neat table (Percent column always shown)
  $table = $summary | Select-Object Status, Count, @{Name='Percent';Expression={ $_.Percent }}
        Write-Host "`nAudit summary:" -ForegroundColor Cyan
        $table | Format-Table -AutoSize

        # Optionally show samples
        if ($ShowSamples) {
            Write-Host "`nSamples per status:" -ForegroundColor Cyan
            $results | Group-Object -Property Status | ForEach-Object {
                $name = $_.Name
                Write-Host "`n=== $name ($($_.Count)) ===" -ForegroundColor Yellow
                ($_.Group | Select-Object -First $Sample -ExpandProperty Path) | ForEach-Object {
                    Write-Host "  $_"
                }
            }
        }

        # Optionally show Fixable items without proposals
        if ($ShowFixableNoProposals) {
            Write-Host "`nFixable items with no proposed fixes:" -ForegroundColor Cyan
            $noProposals = $results |
              Where-Object { $_.Status -ieq 'Fixable' -and (-not $_.Fixes -or $_.Fixes.Count -eq 0) } |
              Select-Object Path, NeedsStructureFix, Status

            if (-not $noProposals -or $noProposals.Count -eq 0) {
                Write-Host "  (none)" -ForegroundColor Green
            } else {
                $noProposals | Format-Table -AutoSize
            }
        }

        # Optionally write summary to OutFile (CSV or JSON)
        if ($OutFile) {
            $ext = [IO.Path]::GetExtension($OutFile).ToLower()
            switch ($ext) {
                '.json' { $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile; Write-Host "Summary written to $OutFile" }
                '.csv'  { $summary | Export-Csv -Path $OutFile -NoTypeInformation; Write-Host "Summary written to $OutFile" }
                default { Write-Error "Unsupported OutFile extension. Use .json or .csv" }
            }
        }

        # Emit the structured summary object for scripting
        [PSCustomObject]@{
            Total = $total
            Summary = $summary
            FixableNoProposals = if ($ShowFixableNoProposals) { $noProposals } else { @() }
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
