Describe 'Heuristics: PreferredExtension' {
    It 'should pick preferred extension when multiple candidates exist' {
        $tmp = New-TemporaryFile
        Remove-Item $tmp -Force
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $cue = Join-Path $tmp 'album.cue'
        $audio1 = Join-Path $tmp 'track01.flac'
        $audio2 = Join-Path $tmp 'track01.mp3'
        Set-Content -LiteralPath $audio1 -Value '' -Encoding UTF8
        Set-Content -LiteralPath $audio2 -Value '' -Encoding UTF8
        Set-Content -LiteralPath $cue -Value 'FILE "track01" MP3' -Encoding UTF8

        $lines = Get-Content -LiteralPath $cue
        $files = Get-ChildItem -LiteralPath $tmp -File

        $heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
        . (Join-Path $heuristicsPath 'PreferredExtension.ps1')
        . (Join-Path $heuristicsPath 'HeuristicsEngine.ps1')

        $candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.flac','.mp3') }
        $pe = $candidates | Where-Object { $_.Heuristic -eq 'PreferredExtension' }
        $pe | Should -Not -BeNullOrEmpty
        $pe[0].Candidate | Should -Match 'track01.flac'

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}






