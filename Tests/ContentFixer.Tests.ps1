Describe 'ContentFixer' {
    It 'Detects and returns fixed text when UpdatedLines differ' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $sampleCue = Join-Path $repoRoot 'Tests\Fixtures\album.cue'

        # Ensure module imported so Get-CueContentFix is available
        Import-Module (Join-Path $repoRoot 'CueFixer.psm1') -Force | Out-Null

    $lines = Get-Content -LiteralPath $sampleCue -Encoding UTF8

        # Simulate updated lines where INDEX 01 is added to track
        $updated = $lines | ForEach-Object {
            if ($_ -match 'TRACK 01') { $_; "    INDEX 01 00:00:00" } else { $_ }
        }

        $res = Get-CueContentFix -CueFilePath $sampleCue -UpdatedLines $updated

        $res.Changed | Should -Be $true
        $res.FixedText | Should -Match 'INDEX 01 00:00:00'
    }
}







