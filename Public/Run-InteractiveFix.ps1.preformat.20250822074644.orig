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
function Invoke-InteractiveFix {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Collections.ArrayList]$CueFiles
    )

    process {
        Invoke-InteractiveFixImpl -CueFiles $CueFiles
    }
}










