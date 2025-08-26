# Debug script for PreferredExtension heuristic
$heuristicsPath = Join-Path $PSScriptRoot '..\Lib\Heuristics'
. (Join-Path $heuristicsPath 'PreferredExtension.ps1')
. (Join-Path $heuristicsPath 'HeuristicsEngine.ps1')

$tmp = New-TemporaryFile
Remove-Item $tmp -Force
New-Item -ItemType Directory -Path $tmp | Out-Null
$cue = Join-Path $tmp 'album.cue'
$audio1 = Join-Path $tmp 'track01.flac'
$audio2 = Join-Path $tmp 'track01.mp3'
Set-Content -LiteralPath $audio1 -Value '' -Encoding UTF8
Set-Content -LiteralPath $audio2 -Value '' -Encoding UTF8
Set-Content -LiteralPath $cue -Value 'FILE "track01" MP3' -Encoding UTF8

Write-Verbose "Files in ${tmp}:"
Get-ChildItem -LiteralPath $tmp -File | ForEach-Object { Write-Verbose " - $($_.Name) (Extension=$($_.Extension))" }

$lines = Get-Content -LiteralPath $cue
$files = Get-ChildItem -LiteralPath $tmp -File
$candidates = Invoke-HeuristicsEngine -CueFilePath $cue -CueLines $lines -CueFolderFiles $files -Context @{ validAudioExts = @('.flac','.mp3') }

Write-Verbose "Candidates count: $($candidates.Count)"
if ($candidates.Count -gt 0) { $candidates | Format-List -Force }

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Verbose "Debug done"





