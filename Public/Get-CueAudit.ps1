<#
.SYNOPSIS
Performs an audit of one or more .cue files and returns structured audit objects.

.DESCRIPTION
`Get-CueAudit` scans the provided path(s) for .cue files (optionally recursively)
and returns an object per file describing its status (Clean, Fixable, Unfixable),
proposed fixes, updated lines and structural errors.

.PARAMETER Path
Path to a .cue file or folder containing .cue files. Accepts pipeline input.

.PARAMETER Recurse
If specified and a folder path is provided, search subfolders for .cue files.

.EXAMPLE
Get-CueAudit -Path 'C:\Music\Album' -Recurse

.EXAMPLE
Get-ChildItem -Filter *.cue | Get-CueAudit

.NOTES
This cmdlet delegates pure analysis to `Get-CueAuditCore` and does not modify files.
#>
function Get-CueAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Path,
        [switch]$Recurse
    )

    process {
        foreach ($p in $Path) {
            $files = if ($Recurse) { Get-ChildItem -LiteralPath $p -Filter *.cue -File -Recurse } else { Get-ChildItem -LiteralPath $p -Filter *.cue -File }
            foreach ($f in $files) {
                Get-CueAuditCore -CueFilePath $f.FullName
            }
        }
    }
}

Export-ModuleMember -Function Get-CueAudit









