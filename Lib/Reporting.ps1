
function Get-AuditSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Results
    )

    # reference param to avoid unused-parameter analyzer warnings
    $null = $Results

    # be defensive: cast status to string, trim whitespace, compare case-insensitively
    $clean = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Clean' }).Count
    $fixable = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Fixable' }).Count
    $unfixable = ($Results | Where-Object { ([string]($_.Status)).Trim() -ieq 'Unfixable' }).Count

    return [PSCustomObject]@{
        Clean = $clean
        Fixable = $fixable
        Unfixable = $unfixable
    }
}




