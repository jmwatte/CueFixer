<#
CueFixer.psm1

This module file safely defines the functions from the legacy `cleanCueFiles.ps1`
without executing any top-level script body. It reads the script, extracts function
definitions and evaluates them in the module scope, then exports the public API.
#>

function Get-FunctionBlocksFromScript {
    param([string]$ScriptPath)
    $lines = Get-Content -LiteralPath $ScriptPath -ErrorAction Stop

    $blocks = @()
    $inFunc = $false
    $braceCount = 0
    $buffer = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if (-not $inFunc -and $line -match '^[ \t]*function\s+[\w-]+') {
            $inFunc = $true
        }

        if ($inFunc) {
            $buffer.Add($line) | Out-Null
            # count braces to detect function end
            $braceCount += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
            $braceCount -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count

            if ($braceCount -le 0) {
                $blocks += ($buffer -join "`r`n")
                $buffer.Clear()
                $inFunc = $false
                $braceCount = 0
            }
        }
    }

    return $blocks
}

$scriptPath = Join-Path $PSScriptRoot 'cleanCueFiles.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Throw "Missing script: $scriptPath"
}

# Module configuration will be provided by Lib/ModuleConfig.ps1 (dot-sourced below)

<#
Legacy import removed: previously we extracted function blocks from the original
`cleanCueFiles.ps1` and evaluated them here. That approach pulled in commands
with unapproved verbs and top-level side-effects. Instead, prefer migrating
functions into `Lib/` and public wrappers into `Public/` and dot-source those
directories (done below).

If you still need to load the legacy script for compatibility, load it
explicitly and intentionally; for example:

    . $scriptPath

But avoid doing that automatically at module import time.
#>
if (Test-Path -LiteralPath $scriptPath) {
    Write-Verbose "Legacy script present at $scriptPath; not auto-importing legacy functions. See README for migration steps."
}

# Dot-source library files (load ModuleConfig first)
$libDir = Join-Path $PSScriptRoot 'Lib'
if (Test-Path $libDir) {
    $config = Join-Path $libDir 'ModuleConfig.ps1'
    if (Test-Path $config) { . $config }
    Get-ChildItem -Path $libDir -Filter *.ps1 -File | Where-Object { $_.Name -ne 'ModuleConfig.ps1' } | ForEach-Object { . $_.FullName }
}

# Dot-source public wrappers
$publicDir = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter *.ps1 -File | ForEach-Object { . $_.FullName }
}

# Export a minimal, stable public surface
Export-ModuleMember -Function @(
    'Get-CueAudit', 'Get-CueAuditCore', 'Get-CueContentFix', 'Apply-Fixes', 'Set-CueFileStructure', 'Repair-CueFile', 'Invoke-InteractiveFix',
    'Open-InEditor', 'Show-Fixables', 'Show-Unfixables', 'Show-AuditSummary'
)





