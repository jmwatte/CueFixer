<#
.SYNOPSIS
  Show detailed diagnostic for a CueFixer audit item.

.DESCRIPTION
  Loads CLIXML/JSON/CSV or accepts piped-in audit results and shows a detailed diagnostic for a single Path
  or the first matching Status (Clean/Fixable/Unfixable). Useful when triaging a single file.

.PARAMETER InputFile
  Path to CLIXML/CSV/JSON produced by Get-CueAudit.

.PARAMETER Results
  Pass results as objects (ValueFromPipeline).

.PARAMETER Path
  The exact Path to show diagnostic for. If omitted, first match for -FirstStatus is used.

.PARAMETER FirstStatus
  Status to pick the first matching item from when -Path is not provided.

.PARAMETER ShowFixes
  Switch: show proposed Fixes and their line ranges.

.PARAMETER ShowFileContent
  Switch: show the original cue file contents (first 200 lines by default).

.PARAMETER MaxFileLines
  Max lines to show when -ShowFileContent is used. Default: 200.
#>
[CmdletBinding(DefaultParameterSetName='File')]
param(
    [Parameter(ParameterSetName='File', Position=0)]
    [string]$InputFile,

    [Parameter(ValueFromPipeline=$true, ParameterSetName='Pipeline')]
    [object[]]$Results,

    [string]$Path,
    [ValidateSet('Clean','Fixable','Unfixable','Unknown')]
    [string]$FirstStatus = 'Fixable',

    [switch]$ShowFixes = $false,
    [switch]$ShowFileContent = $false,
    [int]$MaxFileLines = 200
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
        $collected += $Results
    }
}

end {
    try {
        if (-not $collected -or $collected.Count -eq 0) {
            if ($InputFile) { $collected = Import-ResultsFromFile -Path $InputFile }
            else { Write-Error "No input provided. Provide -InputFile or pipe objects to the script."; return }
        }

        $results = @($collected)

        # find the requested item
        $item = $null
        if ($Path) {
            $item = $results | Where-Object { $_.Path -ieq $Path } | Select-Object -First 1
        } else {
            $item = $results | Where-Object { $_.Status -ieq $FirstStatus } | Select-Object -First 1
        }

        if (-not $item) { Write-Error "No matching audit item found for Path='$Path' Status='$FirstStatus'"; return }

        Write-Host "Audit Diagnostic for: $($item.Path)" -ForegroundColor Cyan
        Write-Host "  Status: $($item.Status)" -ForegroundColor Yellow
        if ($item.PSObject.Properties.Match('NeedsStructureFix')) {
            Write-Host "  NeedsStructureFix: $($item.NeedsStructureFix)"
        }
        if ($item.PSObject.Properties.Match('StructureErrors')) {
            Write-Host "  StructureErrors: "
            $item.StructureErrors | ForEach-Object { Write-Host "    $_" }
        }

        if ($ShowFixes) {
            Write-Host "\nProposed Fixes:" -ForegroundColor Cyan
            if ($item.Fixes -and $item.Fixes.Count -gt 0) {
                $item.Fixes | ForEach-Object {
                    Write-Host "- Description: $($_.Description)"
                    if ($_.Lines) { Write-Host "  Lines: $($_.Lines)" }
                    if ($_.Patch) { Write-Host "  Patch: $($_.Patch)" }
                }
            } else { Write-Host "  (none)" -ForegroundColor Green }
        }

        if ($ShowFileContent) {
            $cuePath = [System.Management.Automation.WildcardPattern]::Escape($item.Path)
            if (Test-Path $cuePath) {
                Write-Host "\nFile content preview (first $MaxFileLines lines):" -ForegroundColor Cyan
                Get-Content -Path $cuePath -TotalCount $MaxFileLines | ForEach-Object { Write-Host "  $_" }
            } else { Write-Host "Original cue file not found at $cuePath" -ForegroundColor Red }
        }

        # emit the item object for scripting
        $item
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
