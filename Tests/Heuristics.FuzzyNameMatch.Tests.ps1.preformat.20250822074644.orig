Describe 'Heuristics: FuzzyNameMatch' {
    It 'should propose a candidate for a near-typo filename' {
        $tmp = New-TemporaryFile; Remove-Item $tmp -Force; New-Item -ItemType Directory -Path $tmp | Out-Null
        $cue = Join-Path $tmp 'album.cue'
        $audio = Join-Path $tmp '01-track-one.mp3'
        Set-Content -LiteralPath $audio -Value '' -Encoding UTF8
        Set-Content -LiteralPath $cue -Value 'FILE "01 track one" MP3' -Encoding UTF8

        $lines = Get-Content -LiteralPath $cue
        $files = Get-ChildItem -LiteralPath $tmp -File

        $heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
        . (Join-Path $heuristicsPath 'FuzzyNameMatch.ps1')
        . (Join-Path $heuristicsPath 'HeuristicsEngine.ps1')

        $candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.mp3') }
        $fuzzy = $candidates | Where-Object { $_.Heuristic -eq 'FuzzyNameMatch' }
        $fuzzy | Should -Not -BeNullOrEmpty
        $fuzzy[0].Candidate | Should -Match '01-track-one.mp3'

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }

    It 'should not propose a candidate for clearly different names' {
        $tmp = New-TemporaryFile; Remove-Item $tmp -Force; New-Item -ItemType Directory -Path $tmp | Out-Null
        $cue = Join-Path $tmp 'album.cue'
        $audio = Join-Path $tmp 'completely-different.mp3'
        Set-Content -LiteralPath $audio -Value '' -Encoding UTF8
        Set-Content -LiteralPath $cue -Value 'FILE "track01" MP3' -Encoding UTF8

        $lines = Get-Content -LiteralPath $cue
        $files = Get-ChildItem -LiteralPath $tmp -File

        $heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
        . (Join-Path $heuristicsPath 'FuzzyNameMatch.ps1')
        . (Join-Path $heuristicsPath 'HeuristicsEngine.ps1')

        $candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.mp3') }
        $fuzzy = $candidates | Where-Object { $_.Heuristic -eq 'FuzzyNameMatch' }
        $fuzzy | Should -BeNullOrEmpty

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}






