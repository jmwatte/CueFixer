function Get-AuditMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    # Defensive parsing: treat Status as string, trim and compare case-insensitively
    $clean = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Clean' }).Count
    $fixable = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Fixable' }).Count
    $unfixable = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Unfixable' }).Count
    $total = $Results.Count

    $fixablePercent = if ($total -eq 0) { 0 } else { [math]::Round(100.0 * $fixable / $total, 1) }

    return [PSCustomObject]@{
        Clean = $clean
        Fixable = $fixable
        Unfixable = $unfixable
        Total = $total
        FixablePercent = $fixablePercent
    }
}
