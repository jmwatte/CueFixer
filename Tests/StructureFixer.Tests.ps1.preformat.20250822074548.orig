Describe 'Set-CueFileStructure / Repair-CueFile' {
    BeforeAll {
        # Load the library implementation directly to avoid wrapper recursion and binding edge-cases
        . (Join-Path $PSScriptRoot '..\Lib\StructureFixer.ps1')
    }

    It 'creates a backup and applies structural fixes' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "test-structure.cue"
        @(
            'TITLE "Album"',
            'PERFORMER "Artist"',
            'FILE "track01.wav" WAVE',
            '  TRACK 01 AUDIO'
        ) | Set-Content -LiteralPath $tmp -Encoding UTF8 -Force

        # Call the library function directly to avoid wrapper-binding edge cases in the test runspace
        $res = Set-CueFileStructure -CueFilePath $tmp -WriteChanges
        $res.Changed | Should -Be $true

        Test-Path "$tmp.bak" | Should -BeTrue

        Remove-Item $tmp, "$tmp.bak" -ErrorAction SilentlyContinue
    }
}




