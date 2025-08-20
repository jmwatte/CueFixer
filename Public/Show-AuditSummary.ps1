<#
.SYNOPSIS
Print a short summary (counts) of cue audit results.

.DESCRIPTION
`Show-AuditSummary` takes audit result objects and prints a concise summary
showing counts of clean, fixable and unfixable files. Useful at the end of a
scan to get a quick overview.

.PARAMETER Results
Audit result objects produced by `Get-CueAudit`.

.EXAMPLE
Get-CueAudit -Path . | Show-AuditSummary
#>
function Show-AuditSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Results
    )

    process {
        $summary = Get-AuditSummary -Results $Results
        Write-Host "`n📊 Cue File Audit Summary:" -ForegroundColor Cyan
        Write-Host "✅ Clean: $($summary.Clean)"
        Write-Host "🛠 Fixable: $($summary.Fixable)"
        Write-Host "🛑 Manual Fix Needed: $($summary.Unfixable)"
    }
}
