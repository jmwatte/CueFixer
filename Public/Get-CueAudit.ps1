<#
.SYNOPSIS
Performs an audit of one or more .cue files and returns structured audit objects.

.DESCRIPTION
Scans the provided path(s) for .cue files (optionally recursively) and writes an
audit object per file describing its status (Clean, Fixable, Unfixable), proposed
fixes, and structural errors. Analysis is delegated to Get-CueAuditCore. This
wrapper is intentionally non-destructive and supports -WhatIf/-Confirm.

.PARAMETER CuePath
CuePath to a .cue file or folder containing .cue files. Accepts pipeline input.

.PARAMETER Recurse
If specified and a folder path is provided, search subfolders for .cue files.

.EXAMPLE
Get-CueAudit -Path 'C:\Music\Album' -Recurse

.EXAMPLE
Get-ChildItem -Filter *.cue | Get-CueAudit

.NOTES
Run with -WhatIf to preview the files that would be audited.
#>
param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string[]]$CuePath,
    [switch]$Recurse,
    [switch]$WhatIf,
    [switch]$Confirm,
    [string]$OutFile,
    [ValidateSet('clixml','csv','json')] [string]$OutFormat = 'clixml'
)

function Get-CueAudit {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$CuePath,
        [switch]$Recurse,
        [string]$OutFile,
        [ValidateSet('clixml','csv','json')] [string]$OutFormat = 'clixml'
    )

    begin {
        $results = @()
    }

    process {
        foreach ($p in $CuePath) {
            if (-not (Test-Path -LiteralPath $p)) {
                Write-Warning "CuePath not found: $p"
                continue
            }

            # Resolve the path item to decide if it's a file or folder
            try {
                $item = Get-Item -LiteralPath $p -ErrorAction Stop
            }
            catch {
                $msg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
                Write-Warning ([string]::Format('Failed to access path {0}: {1}', $p, $msg))
                continue
            }

            if ($item.PSIsContainer) {
                try {
                    $files = if ($Recurse) {
                        Get-ChildItem -LiteralPath $p -Filter *.cue -File -Recurse -ErrorAction Stop
                    }
                    else {
                        Get-ChildItem -LiteralPath $p -Filter *.cue -File -ErrorAction Stop
                    }
                }
                catch {
                    $msg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
                    Write-Warning ([string]::Format('Failed to enumerate CUE files under {0}: {1}', $p, $msg))
                    continue
                }
            }
            else {
                # Single file path provided
                if ([string]::Equals([System.IO.Path]::GetExtension($item.FullName), '.cue', 'OrdinalIgnoreCase')) {
                    $files = @($item)
                }
                else {
                    Write-Warning "Not a .cue file: $p"
                    continue
                }
            }

            foreach ($f in $files) {
                if ($PSCmdlet.ShouldProcess($f.FullName, 'Audit .cue file')) {
                    if (Get-Command -Name Get-CueAuditCore -ErrorAction SilentlyContinue) {
                        try {
                            $res = Get-CueAuditCore -CueFilePath $f.FullName
                            if ($res -ne $null) { $results += $res }
                        }
                        catch {
                            $msg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
                            Write-Warning ([string]::Format('Audit failed for {0}: {1}', $f.FullName, $msg))
                        }
                    }
                    else {
                        Write-Warning 'Get-CueAuditCore not found in session; import module or run this script from the module folder.'
                        return
                    }
                }
            }
        }
    }

    end {
        # Emit collected results to pipeline
        foreach ($r in $results) { Write-Output $r }

        if ($PSBoundParameters.ContainsKey('OutFile') -and $OutFile) {
            switch ($OutFormat) {
                'clixml' { $results | Export-Clixml -Path $OutFile -Force }
                'csv'   { $results | Export-Csv -Path $OutFile -NoTypeInformation -Force }
                'json'  { $results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8 }
            }
        }
    }
}

# Only export when this file is executed as part of a module. Guard and
# swallow errors so dot-sourcing this file in a normal session doesn't fail.
if ((Test-Path Variable:PSModuleInfo) -and ($null -ne $PSModuleInfo)) {
    try {
        Export-ModuleMember -Function Get-CueAudit -ErrorAction Stop
    }
    catch {
        Write-Verbose "Export-ModuleMember skipped during dot-sourcing or restricted session: $($_.Exception.Message)"
    }
}

# If the script file is executed directly and parameters were provided, forward them to the function.
# This lets users run the script as: .\Public\Get-CueAudit.ps1 -Path 'D:\' -Recurse -WhatIf
if ($PSCommandPath -and ($CuePath -or $args.Count -gt 0)) {
    try {
        Get-CueAudit -CuePath $CuePath -Recurse:$Recurse -WhatIf:$WhatIf -Confirm:$Confirm
    }
    catch {
        Write-Error $_.ToString()
    }
    return
}










