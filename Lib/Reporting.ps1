function Get-AuditSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Results
    )

    $clean = ($Results | Where-Object { $_.Status -eq 'Clean' }).Count
    $fixable = ($Results | Where-Object { $_.Status -eq 'Fixable' }).Count
    $unfixable = ($Results | Where-Object { $_.Status -eq 'Unfixable' }).Count

    return [PSCustomObject]@{
        Clean = $clean
        Fixable = $fixable
        Unfixable = $unfixable
    }
}
