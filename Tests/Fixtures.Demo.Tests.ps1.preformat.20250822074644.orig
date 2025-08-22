Describe 'Fixtures demo smoke test' {
    It 'Repair-CueFile -DryRun produces the expected fixed cue' {
        # compute repo root and import module
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $modulePath = Join-Path $repoRoot 'CueFixer.psm1'
        Import-Module $modulePath -Force | Out-Null

        $fixtures = Join-Path $repoRoot 'Tests\Fixtures'
        $expectedPath = Join-Path $repoRoot 'examples\expected\album-fixed.cue'

    $expected = (Get-Content -LiteralPath $expectedPath -Raw) -replace "`r`n","`n"

        $audits = Get-CueAudit -Path $fixtures -Recurse -ErrorAction Stop
        $results = $audits | Repair-CueFile -DryRun

        $targetPath = Join-Path $fixtures 'album.cue'
        $proposed = $results | Where-Object { $_.Path -eq $targetPath } | Select-Object -ExpandProperty Proposed

    # normalize newlines for comparison and remove trailing newlines so the
    # assertion is not sensitive to a final newline character.
    $proposedNormalized = ($proposed -replace "`r`n","`n")
    $expectedNormalized = $expected

        # Robust normalization: normalize CRLF, trim end-of-line whitespace,
        # remove trailing empty lines, then compare.
        $normalize = {
            param($text)
            $s = [string]$text
            $s = $s -replace "`r`n","`n"
            $s = $s -replace "`r","`n"
            $lines = $s -split "`n"
            $lines = $lines | ForEach-Object { $_.TrimEnd() }
            # remove trailing empty lines
            while ($lines.Count -gt 0 -and ($lines[-1] -eq '')) { $lines = $lines[0..($lines.Count-2)] }
            return ($lines -join "`n")
        }

    $expectedFinal = & $normalize $expectedNormalized
    $proposedFinal = & $normalize $proposedNormalized

    # split into lines and defensively trim end-of-line whitespace
    $expectedLines = ($expectedFinal -split "`n") | ForEach-Object { $_.TrimEnd() }
    $proposedLines = ($proposedFinal -split "`n") | ForEach-Object { $_.TrimEnd() }

    # remove trailing empty lines
    while ($expectedLines.Count -gt 0 -and ($expectedLines[-1] -eq '')) { $expectedLines = $expectedLines[0..($expectedLines.Count-2)] }
    while ($proposedLines.Count -gt 0 -and ($proposedLines[-1] -eq '')) { $proposedLines = $proposedLines[0..($proposedLines.Count-2)] }

    # Assert arrays are identical; Compare-Object returns nothing when equal
    (Compare-Object -ReferenceObject $expectedLines -DifferenceObject $proposedLines -SyncWindow 0) | Should -BeNullOrEmpty
    }
}






