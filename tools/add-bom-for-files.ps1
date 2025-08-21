$files = @(
    'Lib\ApplyFixes.ps1',
    'Lib\Interactive.ps1'
)

foreach ($f in $files) {
    $p = Join-Path (Split-Path $PSScriptRoot -Parent) $f
    if (Test-Path -LiteralPath $p) {
        $text = Get-Content -LiteralPath $p -Raw
        $encoding = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($p, $text, $encoding)
    Write-Output "Rewrote with BOM: $p"
    Write-Verbose "add-bom: processed $f"
    }
    else {
        Write-Output "Missing: $p"
    }
}


