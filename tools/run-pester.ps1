<#
.SYNOPSIS
Safe wrapper to run Pester v5 using the -Script hashtable form.

.DESCRIPTION
This script avoids command-line parsing/quoting issues when invoking Pester
from a single pwsh -Command one-liner. Use `pwsh -File .\tools\run-pester.ps1`
or run it from an interactive pwsh session.

.PARAMETER TestsPath
Path to the tests folder or file (default: .\Tests).

.PARAMETER Output
Pester output mode (Detailed, Summary, etc.). Default: Detailed.

.PARAMETER EnableExit
If specified, the script will `exit` with the Invoke-Pester exit code.
#>
param(
    [string]$TestsPath = '.\Tests',
    [string]$Output = 'Detailed',
    [switch]$EnableExit
)

$null = $Output

try {
    Import-Module Pester -ErrorAction Stop -Force
}
catch {
    Write-Error "Failed to load Pester: $_"
    if ($EnableExit) { exit 2 }
    return
}

try {
    $absPath = Resolve-Path -Path $TestsPath -ErrorAction Stop
}
catch {
    Write-Error "Tests path not found: $TestsPath"
    if ($EnableExit) { exit 3 }
    return
}

Write-Verbose "Running Invoke-Pester against: $($absPath.ProviderPath)"

# Invoke Pester using a plain path string to avoid legacy parameter-set parsing issues
$rc = 0
try {
    # Call Invoke-Pester with a plain path to avoid parameter-set conflicts
    Invoke-Pester -Script $absPath.ProviderPath -EnableExit:$false
    $rc = $LASTEXITCODE
}
catch {
    Write-Error "Invoke-Pester failed: $_"
    $rc = 1
}

Write-Verbose "Pester finished (exit code $rc)"
if ($EnableExit) { exit $rc } else { return $rc }











