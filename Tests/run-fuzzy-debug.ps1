. .\..\Lib\Heuristics\HeuristicsEngine.ps1
$cue = Join-Path (Get-Location) 'tmpdebug'
if (Test-Path $cue) { Remove-Item -LiteralPath $cue -Recurse -Force }
New-Item -Path $cue -ItemType Directory | Out-Null
Set-Content -LiteralPath (Join-Path $cue 'album.cue') -Value 'FILE "track01" MP3' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $cue 'completely-different.mp3') -Value '' -Encoding UTF8
$lines = Get-Content -LiteralPath (Join-Path $cue 'album.cue')
$files = Get-ChildItem -LiteralPath $cue -File
try { $c = Invoke-HeuristicsEngine -CueFilePath (Join-Path $cue 'album.cue') -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.mp3') }; $c | Format-List -Force } catch { $_ | Format-List -Force }
Remove-Item -LiteralPath $cue -Recurse -Force


