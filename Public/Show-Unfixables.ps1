<#
.SYNOPSIS
Display unfixable issues discovered by `Get-CueAudit`.

.DESCRIPTION
`Show-Unfixable` accepts audit result objects and prints files with issues that
require manual intervention (for example missing audio files or ambiguous
references). Use this to triage items before attempting automated fixes.

.PARAMETER Results
Audit result objects produced by `Get-CueAudit`.

.EXAMPLE
Get-CueAudit -Path . | Show-Unfixable
#>
function Show-Unfixable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Results
    )

    process {
        foreach ($cue in $Results | Where-Object { $_.Status -eq 'Unfixable' }) {
            Write-Verbose "`n\ud83d\uded1 Manual Fix Needed: $($cue.Path)"
        }
    }
}











