Describe 'Repair-CueFile -WhatIf behavior' {
    It 'does not write changes when -WhatIf is used' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString() + '.cue')
        $content = @'
REM Example
FILE "track.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Track 1"
'@
        Set-Content -Path $tmp -Value $content -Encoding UTF8

    # Run Repair-CueFile with WhatIf in-process
    Import-Module (Join-Path (Get-Location) 'CueFixer.psm1') -Force
    Repair-CueFile -Path $tmp -WhatIf | Out-Null

    # The file should remain unchanged and no .bak created
    $after = Get-Content -Path $tmp -Raw -Encoding UTF8
    # normalize trailing newlines to avoid Set-Content adding a final CRLF
    $afterTrim = $after.TrimEnd("`r","`n")
    $expectedTrim = $content.TrimEnd("`r","`n")
    $afterTrim | Should -BeExactly $expectedTrim
        (Test-Path ($tmp + '.bak')) | Should -BeFalse

        Remove-Item -Path $tmp -Force
    }
}









