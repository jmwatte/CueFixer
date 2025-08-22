<#
.SYNOPSIS
Non-destructive formatting check: copies the repo to a temp folder, runs the formatting helper there, and fails if any file would change.

.OUTPUTS
Exits 0 if formatting matches, non-zero if formatting would change files.
#>

$repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..')
$tempRoot = Join-Path -Path $env:TEMP -ChildPath ("cuefixer-format-check-" + [Guid]::NewGuid().ToString())
New-Item -Path $tempRoot -ItemType Directory | Out-Null
Write-Output "Copying repo to: $tempRoot"

# Use PowerShell copy fallback for portability
Write-Output "Performing copy..."
Copy-Item -Path (Join-Path $repoRoot '*') -Destination $tempRoot -Recurse -Force -ErrorAction Stop

# Run the formatting helper in the temp copy if present
$formatScript = Join-Path $tempRoot 'tools\format-repo.ps1'
if (Test-Path $formatScript) {
    Write-Output "Running format helper in temp copy"
    & pwsh -NoProfile -Command "Set-Location -LiteralPath '$tempRoot'; .\tools\format-repo.ps1" | Out-Null
}
else {
    Write-Error "format-repo.ps1 not found in temp copy; expected at tools/format-repo.ps1"
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
    exit 2
}

# Compare relevant files
$exts = '*.ps1','*.psm1','*.psd1'
$orig = Get-ChildItem -Path $repoRoot -Include $exts -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }
$temp = Get-ChildItem -Path $tempRoot -Include $exts -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }

$differences = @()
foreach ($o in $orig) {
    $rel = $o.FullName.Substring($repoRoot.ProviderPath.Length).TrimStart('\', '/')
    $t = Join-Path $tempRoot $rel
    if (-not (Test-Path $t)) {
        $differences += "MISSING_IN_TEMP: $rel"
        continue
    }
    $oContent = Get-Content -Raw -LiteralPath $o.FullName -ErrorAction Stop
    $tContent = Get-Content -Raw -LiteralPath $t -ErrorAction Stop
    if ($oContent -ne $tContent) {
        $differences += $rel
    }
}

if ($differences.Count -gt 0) {
    Write-Error "Formatting differences detected (files that would change):"
    $differences | ForEach-Object { Write-Error "  $_" }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
    exit 1
}
else {
    Write-Output "Formatting check: OK (no changes would be made)"
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
    exit 0
}







