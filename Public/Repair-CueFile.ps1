<#
.SYNOPSIS
Apply structural fixes to a .cue file and write changes (creates a .bak backup).

.DESCRIPTION
`Repair-CueFile` calls into the library fixer to normalize structure (TRACK/INDEX/FILE
entries) and writes changes to the original file after creating a backup named
`<file>.bak` unless run with `-DryRun`.

.PARAMETER CuePath
CuePath to the .cue file to repair. This parameter accepts pipeline input as a string
or objects that have a `CuePath` property (for example the output of `Get-CueAudit`).

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
    [string]$CuePath,

        [switch]$DryRun,

        # Keep old -Backup switch for compatibility. New behavior: if neither
        # -Backup nor -NoBackup is supplied, default to creating a backup (.bak).
        [switch]$Backup,
        [switch]$NoBackup
    )

    process {
        # support pipeline objects with a CuePath property, and handle cases where
        # the whole object was bound to the $CuePath parameter (PowerShell may try
        # to bind the input object to the parameter by value).
        if ($CuePath -and ($CuePath -isnot [string])) {
            # If $CuePath is an object (not string), prefer its CuePath property when present
            if ($CuePath.PSObject.Properties['CuePath']) {
                $CuePath = $CuePath.CuePath
            }
            else {
                # fallback to looking at the current pipeline object
                if ($_ -and $_.PSObject.Properties['CuePath']) { $CuePath = $_.CuePath }
                else { Write-Verbose "Skipping pipeline input that doesn't contain a CuePath"; return }
            }
        }
        elseif (-not $CuePath) {
            # If no $CuePath param value, try to extract from pipeline object
            if ($_ -is [string]) { $CuePath = $_ }
            elseif ($_ -and $_.PSObject.Properties['CuePath']) { $CuePath = $_.CuePath }
            else { Write-Verbose "Skipping pipeline input that doesn't contain a CuePath"; return }
        }

        if (-not (Test-Path -LiteralPath $CuePath)) {
            Write-Warning "CuePath not found: $CuePath"
            return [PSCustomObject]@{ CuePath = $CuePath; Changed = $false; Error = 'NotFound' }
        }

        $res = Set-CueFileStructure -CueFilePath $CuePath

        if ($res.Changed) {


                if ($DryRun) {
                Write-Verbose "DryRun enabled; not writing changes for $CuePath"
                # return what would have changed
                return [PSCustomObject]@{ CuePath = $CuePath; Changed = $true; DryRun = $true; Proposed = $res.FixedText }
            }

            # Decide whether to create a backup. Default: create a backup unless
            # the caller explicitly requested no backup via -NoBackup. If -Backup
            # was provided preserve that intent.
            $createBackup = $false
            if ($PSBoundParameters.ContainsKey('NoBackup')) { $createBackup = $false }
            elseif ($PSBoundParameters.ContainsKey('Backup')) { $createBackup = $true }
            else { $createBackup = $true } # default to creating backup as per docs

            # Confirm/WhatIf support via Save-FileWithBackup
            if ($PSCmdlet.ShouldProcess($CuePath, 'Write fixed cue file')) {
                $wrote = Save-FileWithBackup -Path $CuePath -Content $res.FixedText -Backup:($createBackup)
                return [PSCustomObject]@{ CuePath = $CuePath; Changed = $wrote; Backup = [bool]$createBackup }
            }
            else {
                return [PSCustomObject]@{ CuePath = $CuePath; Changed = $false; SkippedByShouldProcess = $true }
            }
        }
        else {
            return [PSCustomObject]@{ CuePath = $CuePath; Changed = $false }
        }
    }
}










