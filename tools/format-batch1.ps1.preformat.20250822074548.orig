# Batch formatter: format a small, safe set of files (tools and .vscode/tools)
$files = @(
    '.vscode\tools\add-bom.ps1',
    '.vscode\tools\mcp-client.ps1',
    '.vscode\tools\mcp-proxy.ps1',
    'tools\run-analyzer.ps1',
    'tools\run-analyzer-full.ps1',
    'tools\run-pester.ps1',
    'tools\format-repo.ps1',
    'tools\check-format.ps1',
    'tools\add-bom-for-files.ps1'
)

foreach ($rel in $files) {
    $f = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath $rel
    if (-not (Test-Path $f)) { Write-Warning "Missing: $rel"; continue }
    try {
        $raw = Get-Content -Raw -LiteralPath $f -ErrorAction Stop
    }
    catch { Write-Warning "Read failed: $rel -> $_"; continue }
    $lines = $raw -split "\r?\n"
    $fixed = ($lines | ForEach-Object { $_.TrimEnd() }) -join "`r`n"
    try {
        $fixed | Out-File -LiteralPath $f -Encoding utf8BOM -Force
        Write-Output "Formatted: $rel"
    } catch { Write-Warning "Write failed: $rel -> $_" }
}
Write-Output 'BATCH1_DONE'


