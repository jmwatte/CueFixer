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
        Write-Verbose "`n📊 Cue File Audit Summary:"
        Write-Verbose "✅ Clean: $($summary.Clean)"
        Write-Verbose "🛠 Fixable: $($summary.Fixable)"
        Write-Verbose "🛑 Manual Fix Needed: $($summary.Unfixable)"
    }
}






