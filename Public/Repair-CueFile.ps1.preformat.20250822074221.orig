<#
.SYNOPSIS
Apply structural fixes to a .cue file and write changes (creates a .bak backup).

.DESCRIPTION
`Repair-CueFile` calls into the library fixer to normalize structure (TRACK/INDEX/FILE
entries) and writes changes to the original file after creating a backup named
`<file>.bak` unless run with `-DryRun`.

.PARAMETER Path
Path to the .cue file to repair. This parameter accepts pipeline input as a string
or objects that have a `Path` property (for example the output of `Get-CueAudit`).

.PARAMETER DryRun
When specified, the cmdlet will not write changes to disk. It returns the same
result object but does not create backups or overwrite the original file.

.PARAMETER Backup
When specified, a backup ` <file>.bak` will be created before writing changes.
Defaults to true when writing changes.

.EXAMPLE
Repair-CueFile 'C:\Music\Album\album.cue' -Backup

.EXAMPLE
# Accept pipeline input from Get-CueAudit and perform a dry run
Get-CueAudit -Path .\album | Repair-CueFile -DryRun

.NOTES
This cmdlet modifies files on disk when not run with `-DryRun`. Use `-WhatIf` or
`-Confirm` (supported) to preview destructive operations.
#>
function Repair-CueFile {
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$Path,

        [switch]$DryRun,

        [switch]$Backup
    )

    process {
        # support pipeline objects with a Path property, and handle cases where
        # the whole object was bound to the $Path parameter (PowerShell may try
        # to bind the input object to the parameter by value).
        if ($Path -and ($Path -isnot [string])) {
            # If $Path is an object (not string), prefer its Path property when present
            if ($Path.PSObject.Properties['Path']) {
                $Path = $Path.Path
            }
            else {
                # fallback to looking at the current pipeline object
                if ($_ -and $_.PSObject.Properties['Path']) { $Path = $_.Path }
                else { Write-Verbose "Skipping pipeline input that doesn't contain a Path"; return }
            }
        }
        elseif (-not $Path) {
            # If no $Path param value, try to extract from pipeline object
            if ($_ -is [string]) { $Path = $_ }
            elseif ($_ -and $_.PSObject.Properties['Path']) { $Path = $_.Path }
            else { Write-Verbose "Skipping pipeline input that doesn't contain a Path"; return }
        }

        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Warning "Path not found: $Path"
            return [PSCustomObject]@{ Path = $Path; Changed = $false; Error = 'NotFound' }
        }

        $res = Set-CueFileStructure -CueFilePath $Path

        if ($res.Changed) {
 

                if ($DryRun) {
                Write-Verbose "DryRun enabled; not writing changes for $Path"
                # return what would have changed
                return [PSCustomObject]@{ Path = $Path; Changed = $true; DryRun = $true; Proposed = $res.FixedText }
            }

            # Confirm/WhatIf support via Save-FileWithBackup
            if ($PSCmdlet.ShouldProcess($Path, 'Write fixed cue file')) {
                $wrote = Save-FileWithBackup -Path $Path -Content $res.FixedText -Backup:$Backup
                return [PSCustomObject]@{ Path = $Path; Changed = $wrote; Backup = [bool]$Backup }
            }
            else {
                return [PSCustomObject]@{ Path = $Path; Changed = $false; SkippedByShouldProcess = $true }
            }
        }
        else {
            return [PSCustomObject]@{ Path = $Path; Changed = $false }
        }
    }
}



