<#
Non-interactive harness to exercise Invoke-InteractiveFix for each choice: A,E,P,R,S.
Produces a single JSON report mapping each choice to observed effects.

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\test-interactive-allchoices.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path $PSScriptRoot -Parent
Push-Location $moduleRoot
try {
    $loadedModule = $false
    try {
        Import-Module (Join-Path $moduleRoot 'CueFixer.psd1') -Force -ErrorAction Stop
        $loadedModule = $true
    } catch {
        $loadedModule = $false
    }

    if (-not $loadedModule) {
        # dot-source fallback
        $PSModuleInfo = [pscustomobject]@{ Name='CueFixer'; ModuleBase = $moduleRoot }
        $libDir = Join-Path $moduleRoot 'Lib'
        if (Test-Path $libDir) {
            Get-ChildItem -Path $libDir -Filter *.ps1 -File | Where-Object { $_.Name -ne 'ModuleConfig.ps1' } | ForEach-Object { . $_.FullName }
        }
        $pubDir = Join-Path $moduleRoot 'Public'
        if (Test-Path $pubDir) {
            Get-ChildItem -Path $pubDir -Filter *.ps1 -File | ForEach-Object { . $_.FullName }
        }
        # explicit Interactive.ps1 fallback
        $interactiveFile = Join-Path $libDir 'Interactive.ps1'
        if ((-not (Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue)) -and (Test-Path $interactiveFile)) { . $interactiveFile }
        Remove-Variable PSModuleInfo -ErrorAction SilentlyContinue
    }

    # validate availability
    $hasPublic = [bool](Get-Command Invoke-InteractiveFix -ErrorAction SilentlyContinue)
    $hasImpl   = [bool](Get-Command Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue)
    if (-not ($hasPublic -or $hasImpl)) {
        @{ error = 'Interactive command not available' } | ConvertTo-Json -Depth 5
        exit 2
    }

    # Prepare test folder
    $testDir = Join-Path $env:TEMP 'cuefixer-interactive-allchoices'
    if (Test-Path $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
    New-Item -Path $testDir -ItemType Directory | Out-Null
    $cuePath = Join-Path $testDir 'album.cue'
    $trackPath = Join-Path $testDir 'track01.mp3'
    $cueLines = @(
        'FILE "track01.mp3" MP3',
        'TRACK 01 AUDIO',
        'INDEX 01 00:00:00'
    )
    Set-Content -LiteralPath $cuePath -Value $cueLines -Encoding UTF8
    New-Item -Path $trackPath -ItemType File | Out-Null
    $fileItem = Get-Item -LiteralPath $cuePath
    $alist = [System.Collections.ArrayList]::new(); [void]$alist.Add($fileItem)

    $results = [ordered]@{}
    $choices = @('A','E','P','R','S')
    # Test-only switch: when $ForceFixable is true, the harness fabricates Fixable analysis
    $ForceFixable = $true

    foreach ($choice in $choices) {
        # Setup per-run tracking
        $applied = $false
        $editCalled = $false
        $playCalled = $false
        $analyzeCount = 0

        if ($ForceFixable) {
            # Ensure the implementation is loaded so Invoke-InteractiveFixImpl exists
            $interactiveFile = Join-Path (Join-Path $moduleRoot 'Lib') 'Interactive.ps1'
            if ((-not (Get-Command Invoke-InteractiveFixImpl -ErrorAction SilentlyContinue)) -and (Test-Path $interactiveFile)) { . $interactiveFile }

            # Stub the implementation's audit function so the impl sees Fixable results
            function Get-CueAuditCore { param($CueFilePath) $script:analyzeCount++; return [PSCustomObject]@{ Path=$CueFilePath; Status='Fixable'; Fixes=@([PSCustomObject]@{Old='OLD';New='NEW'}); UpdatedLines=@('a'); NeedsStructureFix=$false } }
        } else {
            # Fallback to the real audit function if available
            function Get-CueAuditCore { param($CueFilePath) $script:analyzeCount++; return & (Get-Command Get-CueAuditCore -CommandType Function -ErrorAction SilentlyContinue) $CueFilePath }
        }
        function Invoke-ApplyFix { param($res) $script:applied = $true }
        function Open-InEditor { param($fp) $script:editCalled = $fp }
        function Start-Process { param($fp,$args) $script:playCalled = $fp }
    # Provide choice non-interactively via environment variable to avoid blocking Read-Host
    $env:CUEFIXER_TEST_CHOICE = $choice

    # Invoke implementation directly when forcing Fixable results for deterministic testing
    if ($ForceFixable) { Invoke-InteractiveFixImpl -cueFiles $alist | Out-Null }
    elseif ($hasPublic) { Invoke-InteractiveFix -cueFiles $alist | Out-Null } else { Invoke-InteractiveFixImpl -cueFiles $alist | Out-Null }

        # Collect results
        $results[$choice] = [ordered]@{
            Applied = [bool]$applied
            EditCalled = if ($editCalled) { $editCalled } else { $false }
            PlayCalled = if ($playCalled) { $playCalled } else { $false }
            AnalyzeCount = [int]$analyzeCount
        }

    # Cleanup stubs and env var
    Remove-Item Function:\Get-CueAuditCore -ErrorAction SilentlyContinue
    Remove-Item Function:\Invoke-ApplyFix -ErrorAction SilentlyContinue
    Remove-Item Function:\Open-InEditor -ErrorAction SilentlyContinue
    Remove-Item Function:\Start-Process -ErrorAction SilentlyContinue
    Remove-Item Env:\CUEFIXER_TEST_CHOICE -ErrorAction SilentlyContinue
    }

    # cleanup
    if (Test-Path $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
    Pop-Location

    $results | ConvertTo-Json -Depth 5

} catch {
    Pop-Location -ErrorAction SilentlyContinue
    @{ error = $_.Exception.Message } | ConvertTo-Json -Depth 5
    exit 1
}
