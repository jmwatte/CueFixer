# Pester v5 tests for Analyze-CueFile
Describe 'Analyze-CueContent' {
    BeforeAll {
        # Import the module file so exported functions are registered as commands
        $moduleFile = Join-Path $PSScriptRoot '..\CueFixer.psm1'
        Remove-Module -Name CueFixer -ErrorAction SilentlyContinue
        Import-Module -Name $moduleFile -Force -ErrorAction Stop
    # module imported; tests call the public Get-CueAudit cmdlet
    }

    It 'returns Clean for a well-formed cue' {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # create an audio file and a matching cue
            New-Item -Path (Join-Path $tmp 'track01.flac') -ItemType File | Out-Null
            $cue = @(
                'REM GENRE "Test"'
                'FILE "track01.flac" WAVE'
                '  TRACK 01 AUDIO'
                '    INDEX 01 00:00:00'
            )
            $cuePath = Join-Path $tmp 'good.cue'
            $cue -join "`r`n" | Set-Content -LiteralPath $cuePath -Encoding UTF8

            $result = Get-CueAudit -Path $cuePath
            $result.Status | Should -Be 'Clean'
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'detects missing extension and offers fix when matching file exists' {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # create audio file with extension, cue references base name without extension
            New-Item -Path (Join-Path $tmp 'song.FLAC') -ItemType File | Out-Null
            $cue = @(
                'FILE "song" WAVE'
                '  TRACK 01 AUDIO'
                '    INDEX 01 00:00:00'
            )
            $cuePath = Join-Path $tmp 'missing-ext.cue'
            $cue -join "`r`n" | Set-Content -LiteralPath $cuePath -Encoding UTF8

            $result = Get-CueAudit -Path $cuePath
            $result.Status | Should -Be 'Fixable'
            $result.Fixes.Count | Should -BeGreaterThan 0
            # one of the proposed fixes should reference the actual file name
            $found = $result.Fixes | Where-Object { $_.New -match 'song\.FLAC' }
            $null -ne $found | Should -Be $true
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'marks as Unfixable when referenced audio missing' {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $cue = @(
                'FILE "does-not-exist.flac" WAVE'
                '  TRACK 01 AUDIO'
                '    INDEX 01 00:00:00'
            )
            $cuePath = Join-Path $tmp 'bad.cue'
            $cue -join "`r`n" | Set-Content -LiteralPath $cuePath -Encoding UTF8

            $result = Get-CueAudit -Path $cuePath
            $result.Status | Should -Be 'Unfixable'
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'detects TRACK before FILE as structural issue' {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $cue = @(
                'TRACK 01 AUDIO'
                '  INDEX 01 00:00:00'
                'FILE "somefile.flac" WAVE'
            )
            $cuePath = Join-Path $tmp 'struct.cue'
            $cue -join "`r`n" | Set-Content -LiteralPath $cuePath -Encoding UTF8

            $result = Get-CueAudit -Path $cuePath
            $result.NeedsStructureFix | Should -Be $true
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}







