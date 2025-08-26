# Repo formatting helper: normalize line endings to CRLF, trim trailing whitespace, and rewrite files with UTF8 BOM
$repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..')
$excludePaths = @('tools\pssa-findings.json','tools\pssa-lib-findings.json','.git','node_modules')
$exts = '*.ps1','*.psm1','*.psd1'
# Repo formatting helper: normalize line endings to CRLF, trim trailing whitespace, and rewrite files with UTF8 BOM
$repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..')
$excludePaths = @('tools\pssa-findings.json','tools\pssa-lib-findings.json','.git','node_modules')
$exts = '*.ps1','*.psm1','*.psd1'

$files = Get-ChildItem -Path $repoRoot -Include $exts -Recurse -File | Where-Object {
    foreach ($ex in $excludePaths) { if ($_.FullName -like "*$ex*") { return $false } }
    return $true
}

foreach ($f in $files) {
    try {
        $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to read $($f.FullName): $_"
        continue
    }

    # Split into lines, trim trailing whitespace, then join with CRLF
    $lines = $raw -split "\r?\n"
    $fixed = ($lines | ForEach-Object { $_.TrimEnd() }) -join "`r`n"

    try {
        $fixed | Out-File -LiteralPath $f.FullName -Encoding utf8BOM -Force
        Write-Output "Rewrote: $($f.FullName)"
    }
    catch {
        Write-Warning "Failed to write $($f.FullName): $_"
    }
}
Write-Output 'FORMAT_REPO_DONE'















