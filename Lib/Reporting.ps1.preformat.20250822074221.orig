function Get-AuditSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Results
    )

    # reference param to avoid unused-parameter analyzer warnings
    $null = $Results

    # Helper: normalize status into a compact lowercase string
    $normalize = {
        param($raw)
        $s = [string]$raw
        # remove control/invisible characters (Unicode category C), then trim and lowercase
        $cleaned = [regex]::Replace($s, '\p{C}+', '')
        return $cleaned.Trim().ToLowerInvariant()
    }

    # compute matches defensively
    $cleanMatches = @()
    $fixableMatches = @()
    $unfixableMatches = @()

    foreach ($it in $Results) {
        try {
            $n = & $normalize ($it.Status)
        } catch {
            # fallback if item doesn't expose .Status
            $n = & $normalize ($it['Status'] 2>$null)
        }

        switch ($n) {
            'clean'    { $cleanMatches += $it }
            'fixable'  { $fixableMatches += $it }
            'unfixable'{ $unfixableMatches += $it }
            default { }
        }
    }

    return [PSCustomObject]@{
        Clean = $cleanMatches.Count
        Fixable = $fixableMatches.Count
        Unfixable = $unfixableMatches.Count
    }
}
