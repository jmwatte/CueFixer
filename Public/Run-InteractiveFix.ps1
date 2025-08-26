<#
.SYNOPSIS
Interactive review and application of repairs for .cue files in a folder.

.DESCRIPTION
`Invoke-InteractiveFix` groups incoming .cue file objects by folder, runs the
audit for each folder, shows fixable and unfixable issues, and offers an
interactive prompt to apply fixes, edit files, or retry analysis. This helper
is intended for interactive use only and delegates heavy lifting to the
`Get-CueAuditCore`, `Apply-Fixes` and Show-* helpers.

.PARAMETER CueFiles
An array of fileinfo-like objects (for example the output of `Get-ChildItem`) or
objects with a `FullName`/`DirectoryName` property. Accepts pipeline input.

.EXAMPLE
Get-ChildItem -Filter *.cue | Invoke-InteractiveFix

.NOTES
This function calls `Apply-Fixes` when the user chooses to apply changes. Use
`Get-CueAudit` and `Repair-CueFile -DryRun` for non-interactive automation.
#>
# Script-level parameters so this file can be executed directly as a script
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [Alias('Path')]
    [string[]]$CuePaths,

    [switch]$Recurse,

    # New display mode switch (optional)
    [switch]$FullCueLeft,

    # Optional: allow -Verbose / common switches from host
    [switch]$WhatIf,
    [switch]$Confirm
)
write-Host "RunInterActivefullcueleft: $($FullCueLeft.IsPresent)" -ForegroundColor DarkCyan
#check if module CueFixer is loaded, if not try to import it
# Import module from workspace root
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'CueFixer.psm1'
# try {
#     if (Test-Path $modulePath) { Import-Module -Name $modulePath -Force -ErrorAction Stop; Write-Host "Imported module from $modulePath" -ForegroundColor Green }
#     else { Write-Warning "Module not found at $modulePath" }
# } catch {
#     Write-Warning "Import-Module failed: $($_.Exception.Message)"
# }

function Invoke-InteractiveFix {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Collections.ArrayList]$CueFiles
    )

    process {
        Invoke-InteractiveFixImpl -CueFiles $CueFiles -FullCueLeft:($FullCueLeft.IsPresent)
    }
}

# If executed directly and a Path was provided, collect cue files and forward to the function
if ($PSCommandPath -and ($CuePaths -or $args.Count -gt 0)) {
   
    
    $items = New-Object System.Collections.ArrayList
    
    foreach ($p in $CuePaths) {
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Warning "Path not found: $p"
            continue
        }

        $it = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
        if ($null -eq $it) { continue }

        if ($it.PSIsContainer) {
            try {
                $found = if ($Recurse) {
                    Get-ChildItem -LiteralPath $p -Filter *.cue -File -Recurse -ErrorAction Stop
                }
                else {
                    Get-ChildItem -LiteralPath $p -Filter *.cue -File -ErrorAction Stop
                }
            
                if ($null -ne $found) {
                    if ($found -is [System.Collections.IEnumerable]) {
                        $items.AddRange($found) | Out-Null
                    }
                    else {
                        # single FileInfo
                        $items.Add($found) | Out-Null
                    }
                }
            }
            catch {
                Write-Warning ([string]::Format('Failed to enumerate CUE files under {0}: {1}', $p, $_.Exception.Message))
            }
        }
        else {
            if ([System.IO.Path]::GetExtension($it.FullName) -ieq '.cue') { $items.Add($it) | Out-Null }
            else { Write-Warning "Not a .cue file: $p" }
        }
    }
    # from plain pwsh
    if ($items.Count -gt 0) {
        # Ensure helper functions are available (Import module or dot-source fallback)
        if (-not (Get-Command -Name Show-Fixable -ErrorAction SilentlyContinue)) {
            $manifest = Join-Path $PSScriptRoot '..\CueFixer.psd1'
            if (Test-Path $manifest) {
                Import-Module $manifest -Force -ErrorAction SilentlyContinue
            }

            if (-not (Get-Command -Name Show-Fixable -ErrorAction SilentlyContinue)) {
                # fallback: dot-source library and public wrappers so functions are defined in this session
                $libDir = Join-Path $PSScriptRoot '..\Lib'
                if (Test-Path $libDir) { Get-ChildItem -Path $libDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName } }
                Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
            }
        }

        # Convert to ArrayList expected by the function
        $alist = New-Object System.Collections.ArrayList
        [void]$alist.AddRange($items)
        Invoke-InteractiveFix -CueFiles $alist
    }
    else {
        Write-Verbose 'No .cue files found for the provided Path(s).'
    }

    return
}













