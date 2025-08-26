Import-Module (Join-Path $PSScriptRoot '..\CueFixer.psd1') -Force

# Create temp file
$tmp = Join-Path $env:TEMP 'cuefixer-test.txt'
"cuefixer test" | Out-File -FilePath $tmp -Encoding utf8 -Force

# Ensure debug stubs are disabled and set editor
Remove-Item Env:CUEFIXER_DEBUG -ErrorAction SilentlyContinue
$env:CUEFIXER_EDITOR = 'notepad'

Write-Verbose "Calling Open-InEditor against $tmp" -Verbose
Open-InEditor -filePath $tmp -Verbose
Start-Sleep -Seconds 1
if (Get-Process -Name notepad -ErrorAction SilentlyContinue) { Write-Host 'Notepad launched' } else { Write-Host 'Notepad NOT found' }
Write-Host "WROTE_TMP: $tmp"

