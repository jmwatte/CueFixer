try {
    Import-Module -Force (Join-Path $PSScriptRoot '..\CueFixer.psd1') -ErrorAction Stop
    Write-Host 'IMPORT_OK'
    $m = Get-Module CueFixer
    if ($m) {
        Write-Host 'ExportedFunctions:'
        $m.ExportedCommands.Keys | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host 'MODULE_NOT_LOADED'
    }
} catch {
    Write-Host 'IMPORT_ERROR:' $_.Exception.Message
    exit 2
}
