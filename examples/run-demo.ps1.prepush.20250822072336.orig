# Demo script to exercise the README "Try it" example.
# Import the module from repo root and run an audit + dry-run repair against Tests\Fixtures.

# Compute repository root reliably relative to this script's folder
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$modulePath = Join-Path $repoRoot 'CueFixer.psm1'

if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found at path: $modulePath"
    exit 1
}

Import-Module $modulePath -Force -Verbose

$fixtures = Join-Path $repoRoot 'Tests\Fixtures'
Write-Host "Running Get-CueAudit against $fixtures..." -ForegroundColor Cyan
$audits = Get-CueAudit -Path $fixtures -Recurse -ErrorAction Stop

Write-Host "Found audits:" -ForegroundColor Cyan
$audits | Format-Table -AutoSize

Write-Host "Running Repair-CueFile in DryRun mode..." -ForegroundColor Cyan
$audits | Repair-CueFile -DryRun -Verbose

Write-Host "Demo complete." -ForegroundColor Green

