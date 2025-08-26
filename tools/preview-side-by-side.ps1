try {
    Import-Module -Force (Join-Path $PSScriptRoot '..\CueFixer.psd1') -ErrorAction Stop
    $fixtureDir = Join-Path (Join-Path $PSScriptRoot '..') 'Tests\Fixtures'
    if (-not (Test-Path $fixtureDir)) { Write-Host "Fixtures not found: $fixtureDir"; exit 2 }
    $files = Get-ChildItem -LiteralPath $fixtureDir -Filter *.cue -File -ErrorAction Stop
    foreach ($f in $files) {
        Write-Host "`n=== Preview for: $($f.FullName) ===`n" -ForegroundColor Cyan
        Show-CueAudioSideBySide -CueFilePath $f.FullName -FolderPath $f.DirectoryName
    }
} catch {
    Write-Host 'ERROR:' $_.Exception.Message -ForegroundColor Red
    exit 2
}
