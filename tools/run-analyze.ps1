try {
    Import-Module -Force (Join-Path $PSScriptRoot '..\CueFixer.psd1') -ErrorAction Stop
    $cue = Join-Path (Join-Path $PSScriptRoot '..') 'Tests\Fixtures\album.cue'
    $res = Analyze-CueFile -CueFilePath $cue
    $res | Format-List -Property *
} catch {
    Write-Host 'ERROR:' $_.Exception.Message
    exit 2
}
