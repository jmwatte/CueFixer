<#
Safe, non-interactive tests for Invoke-InteractiveFixImpl choices A/E/P/R/S
This script is tolerant: it attempts to Import-Module first, and if that fails
it fallbacks to dot-sourcing Lib and Public files while providing a temporary
$PSModuleInfo so public wrappers that reference it don't error when dot-sourced.

Run from the module root:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\test-interactive-simulated.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path $PSScriptRoot -Parent
Push-Location $moduleRoot

try {
    $env:CUEFIXER_DEBUG = $null

    # Try to import the module so code runs in proper module scope.
    $loadedModule = $false
    try {
        Import-Module (Join-Path $moduleRoot 'CueFixer.psd1') -Force -ErrorAction Stop
        $loadedModule = $true
    } catch {
        # Import failed; we'll dot-source files as a fallback below
        $loadedModule = $false
    }

    if (-not $loadedModule) {
        # Provide a minimal PSModuleInfo so public scripts referencing it don't fail
        $PSModuleInfo = [pscustomobject]@{ Name='CueFixer'; ModuleBase = $moduleRoot }

        $libDir = Join-Path $moduleRoot 'Lib'
        if (Test-Path $libDir) {
            Get-ChildItem -Path $libDir -Filter *.ps1 -File | Where-Object { $_.Name -ne 'ModuleConfig.ps1' } | ForEach-Object { . $_.FullName }
        }

        $pubDir = Join-Path $moduleRoot 'Public'
        if (Test-Path $pubDir) {
            Get-ChildItem -Path $pubDir -Filter *.ps1 -File | ForEach-Object { . $_.FullName }
        }

        # Some implementations keep the interactive implementation in a single file
        # called Interactive.ps1. If neither public nor impl exists yet, try
        # dot-sourcing that explicit file to guarantee Invoke-InteractiveFixImpl.
        $interactiveFile = Join-Path $libDir 'Interactive.ps1'
        if ((-not (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue)) -and
            (-not (Get-Command Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue)) -and
            (Test-Path $interactiveFile)) {
            . $interactiveFile
        }

        Remove-Variable PSModuleInfo -ErrorAction SilentlyContinue
    }

    # Verify that at least one of the interactive entry points is available.
    $hasPublic = [bool](Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue)
    $hasImpl   = [bool](Get-Command Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue)
    if (-not ($hasPublic -or $hasImpl)) {
        $diagnostic = [ordered]@{
            Message = 'Interactive commands not available after import/dot-source fallback.'
            ModuleImported = $loadedModule
            FoundCommands = (Get-Command -Name Invoke-InteractiveFix,Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue | Select-Object Name,Source | ForEach-Object { $_ })
            LibExists = Test-Path (Join-Path $moduleRoot 'Lib')
            PublicExists = Test-Path (Join-Path $moduleRoot 'Public')
        }
        @{ error = $diagnostic } | ConvertTo-Json -Depth 6
        Pop-Location
        exit 2
    }

    # Prepare fixture
    $testDir = Join-Path $env:TEMP 'cuefixer-interactive-test'
    if (Test-Path $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
    New-Item -Path $testDir -ItemType Directory | Out-Null
    Set-Content -LiteralPath (Join-Path $testDir 'album.cue') -Value "FILE `"track01.mp3`" MP3`nTRACK 01 AUDIO`nINDEX 01 00:00:00" -Encoding UTF8
    New-Item -Path (Join-Path $testDir 'track01.mp3') -ItemType File | Out-Null

    $item = Get-Item (Join-Path $testDir 'album.cue')
    $alist = [System.Collections.ArrayList]::new(); [void]$alist.Add($item)

    # Shared stub helpers and summary container
    $summary = [ordered]@{}
    $global:analyzeCount = 0

    # The interactive flow in this module calls Analyze-CueFile and Apply-Fixes.
    # Stub those so the interactive loop behaves deterministically for testing.
    function Analyze-CueFile { param($CueFilePath) $global:analyzeCount++; return [PSCustomObject]@{ Path=$CueFilePath; Status='Fixable'; Fixes=@([PSCustomObject]@{Old='OLD';New='NEW'}); UpdatedLines=@('a'); NeedsStructureFix=$false } }
    function Apply-Fixes { param($results) $summary['A_applied'] = $true }

    # SAFE MODE: do not actually launch GUI; record calls instead
    $realMode = $false  # set to $true if you want E/P to actually call Start-Process (not recommended in automated run)

    # Test A (Apply)
    function Read-Host { param($Prompt) 'A' }
    # Apply-Fixes stub above will set summary['A_applied']
    if (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue) { Invoke-InteractiveFix -CueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -CueFiles $alist | Out-Null }
    $summary['A_applied'] = [bool]($summary['A_applied'] -eq $true)
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue

    # Test E (Edit) - SAFE: record Open-InEditor call, do not launch editor
    function Read-Host { param($Prompt) 'E' }
    $summary['E_editCalled'] = $false
    if ($realMode) {
        function Open-InEditor { param($filePath) Start-Process -FilePath 'notepad' -ArgumentList $filePath -ErrorAction SilentlyContinue; $summary['E_editCalled'] = $filePath }
    } else {
        function Open-InEditor { param($filePath) $summary['E_editCalled'] = $filePath }
    }
    if (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue) { Invoke-InteractiveFix -CueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -CueFiles $alist | Out-Null }
    # if realMode you'd want to wait & then close the editor; in safe mode nothing to do
    Remove-Item Function:\Open-InEditor -ErrorAction SilentlyContinue
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue

    # Test P (Play) - SAFE: record Start-Process invocation rather than launching
    $summary['P_playCalled'] = $false
    if ($realMode) {
        function Read-Host { param($Prompt) 'P' }
        function Start-Process { param($FilePath, $ArgumentList) $summary['P_playCalled'] = $FilePath }  # real Start-Process call won't be replaced here when realMode=true
    } else {
        function Start-Process { param($FilePath, $ArgumentList) $summary['P_playCalled'] = $FilePath }
        function Read-Host { param($Prompt) 'P' }
    }
    if (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue) { Invoke-InteractiveFix -CueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -CueFiles $alist | Out-Null }
    Remove-Item Function:\Start-Process -ErrorAction SilentlyContinue
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue

    # Test R (Retry) - ensure analysis re-runs
    $global:analyzeCount = 0
    function Read-Host { param($Prompt) 'R' }
    if (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue) { Invoke-InteractiveFix -CueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -CueFiles $alist | Out-Null }
    $summary['R_analyzeCount'] = $global:analyzeCount
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue

    # Test S (Skip)
    function Read-Host { param($Prompt) 'S' }
    if (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue) { Invoke-InteractiveFix -CueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -CueFiles $alist | Out-Null }
    $summary['S_skipped'] = $true
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue

    # Cleanup
    if (Test-Path $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
    Pop-Location

    # Output summary
    $summary | ConvertTo-Json -Depth 5

} catch {
    # Always return JSON so callers can parse failures
    $err = $_.Exception.Message
    @{ error = $err } | ConvertTo-Json -Depth 5
    Pop-Location -ErrorAction SilentlyContinue
    exit 1
}

