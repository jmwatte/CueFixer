Describe 'Heuristics: ExactNameMatch and ExtensionRecovery' {
    It 'ExactNameMatch should propose a fix when filename matches exactly' {
        $tmp = New-TemporaryFile
        Remove-Item $tmp -Force
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $cue = Join-Path $tmp 'album.cue'
        $audio = Join-Path $tmp 'track01.WAV'
        Set-Content -LiteralPath $audio -Value '' -Encoding UTF8
        Set-Content -LiteralPath $cue -Value 'FILE "track01.WAV" WAVE' -Encoding UTF8

        $lines = Get-Content -LiteralPath $cue
        $files = Get-ChildItem -LiteralPath $tmp -File

    $heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
    Import-Module -Name (Join-Path $heuristicsPath 'HeuristicsEngine.ps1') -Force -ErrorAction SilentlyContinue
    . (Join-Path $heuristicsPath 'ExactNameMatch.ps1')

        $candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{}
        $candidates | Should -Not -BeNullOrEmpty
        $candidates[0].Heuristic | Should -Be 'ExactNameMatch'

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }

    It 'ExtensionRecovery should propose a fix when extension is missing and candidate unique' {
        $tmp = New-TemporaryFile
        Remove-Item $tmp -Force
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $cue = Join-Path $tmp 'album.cue'
        $audio = Join-Path $tmp 'track01.mp3'
        Set-Content -LiteralPath $audio -Value '' -Encoding UTF8
        Set-Content -LiteralPath $cue -Value 'FILE "track01" MP3' -Encoding UTF8

        $lines = Get-Content -LiteralPath $cue
        $files = Get-ChildItem -LiteralPath $tmp -File

    $heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
    . (Join-Path $heuristicsPath 'ExtensionRecovery.ps1')
    . (Join-Path $heuristicsPath 'HeuristicsEngine.ps1')

        $candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.mp3') }
        $candidates | Should -Not -BeNullOrEmpty
        ($candidates | Where-Object { $_.Heuristic -eq 'ExtensionRecovery' }).Count | Should -Be 1

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}


