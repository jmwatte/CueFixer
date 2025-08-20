<#
.SYNOPSIS
Display unfixable issues discovered by `Get-CueAudit`.

.DESCRIPTION
`Show-Unfixables` accepts audit result objects and prints files with issues that
require manual intervention (for example missing audio files or ambiguous
references). Use this to triage items before attempting automated fixes.

.PARAMETER Results
Audit result objects produced by `Get-CueAudit`.

.EXAMPLE
Get-CueAudit -Path . | Show-Unfixables
#>
function Show-Unfixables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Results
    )

    process {
        foreach ($cue in $Results | Where-Object { $_.Status -eq 'Unfixable' }) {
            Write-Host "`n🛑 Manual Fix Needed: $($cue.Path)" -ForegroundColor Red
        }
    }
}
