function Clear-KeyboardBuffer {
    while ([System.Console]::KeyAvailable) {
        [System.Console]::ReadKey($true) | Out-Null
    }
}

## Preferred editor: can be overridden by environment variable CUEFIXER_EDITOR
$preferredEditor = $env:CUEFIXER_EDITOR
if (-not $preferredEditor) { $preferredEditor = 'hx' }