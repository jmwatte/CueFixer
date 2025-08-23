<#
Run a real interactive session for testing Invoke-InteractiveFix.

By default this runner is SAFE: it will import the module and run the interactive
flow but stub out editor/play launches so you can step through prompts without
launching GUIs. Pass -Live to actually open the editor and play files.

Usage (from module root):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\run-interactive-real.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\run-interactive-real.ps1 -Live
#>
param(
    [switch]$Live,
    [string]$ModuleRoot = (Get-Location).Path,
    [string]$TestDir = (Join-Path $env:TEMP 'cuefixer-interactive-real')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Push-Location $ModuleRoot
try {
    Write-Host "Preparing test run in: $ModuleRoot" -ForegroundColor Cyan

    # Import the module if possible
    try {
        Import-Module (Join-Path $ModuleRoot 'CueFixer.psd1') -Force -ErrorAction Stop
        Write-Host 'Module imported.' -ForegroundColor Green
    }
    catch {
        Write-Host 'Module import failed; dot-sourcing Lib/Public as fallback.' -ForegroundColor Yellow
        # Provide minimal PSModuleInfo so public wrappers that reference it don't fail
        $PSModuleInfo = [pscustomobject]@{ Name='CueFixer'; ModuleBase = $ModuleRoot }
        $libDir = Join-Path $ModuleRoot 'Lib'
        if (Test-Path $libDir) {
            Get-ChildItem -Path $libDir -Filter *.ps1 -File | Where-Object { $_.Name -ne 'ModuleConfig.ps1' } | ForEach-Object { . $_.FullName }
        }
        $pubDir = Join-Path $ModuleRoot 'Public'
        if (Test-Path $pubDir) {
            Get-ChildItem -Path $pubDir -Filter *.ps1 -File | ForEach-Object { . $_.FullName }
        }
        Remove-Variable PSModuleInfo -ErrorAction SilentlyContinue
    }

    # Create test directory and sample files
    if (Test-Path $TestDir) { Remove-Item -LiteralPath $TestDir -Recurse -Force }
    New-Item -Path $TestDir -ItemType Directory | Out-Null
    $cuePath = Join-Path $TestDir 'album.cue'
    $trackPath = Join-Path $TestDir 'track01.mp3'
    $cueLines = @(
        'FILE "track01.mp3" MP3'
        'TRACK 01 AUDIO'
        'INDEX 01 00:00:00'
    )
    Set-Content -LiteralPath $cuePath -Value $cueLines -Encoding UTF8
    New-Item -Path $trackPath -ItemType File | Out-Null

    $fileItem = Get-Item -LiteralPath $cuePath
    $alist = [System.Collections.ArrayList]::new(); [void]$alist.Add($fileItem)

    # If not Live, stub Open-InEditor and Start-Process so you don't launch GUIs
    if (-not $Live) {
        if (Get-Command -Name Open-InEditor -CommandType Function -ErrorAction SilentlyContinue) {
            Remove-Item Function:\Open-InEditor -ErrorAction SilentlyContinue
        }
        if (Get-Command -Name Start-Process -CommandType Function -ErrorAction SilentlyContinue) {
            Remove-Item Function:\Start-Process -ErrorAction SilentlyContinue
        }
        function Open-InEditor { param($filePath) Write-Host "[stub] Open-InEditor called for: $filePath" -ForegroundColor Yellow }
        function Start-Process { param($FilePath, $ArgumentList) Write-Host "[stub] Start-Process called for: $FilePath" -ForegroundColor Yellow }
        Write-Host 'Running in SAFE mode — editor/play calls are stubbed. Use -Live to enable real launches.' -ForegroundColor Yellow
    }
    else {
        Write-Host 'Running in LIVE mode — editor and play commands will launch.' -ForegroundColor Green
    }

    # Confirm interactive function exists
    if (-not (Get-Command -Name Invoke-InteractiveFix -ErrorAction SilentlyContinue) -and -not (Get-Command -Name Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue)) {
        Write-Host 'Interactive function not found; aborting.' -ForegroundColor Red
        return
    }

    # Run interactive flow — this will prompt you on the console. Use A/E/P/R/S as prompted.
    if (Get-Command -Name Invoke-InteractiveFix -ErrorAction SilentlyContinue) {
        Invoke-InteractiveFix -cueFiles $alist
    }
    else {
        Invoke-InteractiveFixImpl -cueFiles $alist
    }

} finally {
    Pop-Location
}
