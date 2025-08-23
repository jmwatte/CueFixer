Write-Output '=== Test runner: Get-CueAudit invocation styles ==='

$fixture = Join-Path $PSScriptRoot '..\Tests\Fixtures\album.cue' | Resolve-Path -ErrorAction SilentlyContinue
if (-not $fixture) {
    Write-Error 'Fixture file not found.'; exit 2
}
$fixture = $fixture.Path

# 1) Run script file with -Path parameter
Write-Output "\n--- 1) Script invocation with -Path ---"
try {
    & "$PSScriptRoot\..\Public\Get-CueAudit.ps1" -Path $fixture -WhatIf
    Write-Output '-> Script with -Path executed (no error).'
}
catch {
    Write-Output '-> Script with -Path ERROR:'
    Write-Output $_.ToString()
}

# 2) Run script file with positional arg
Write-Output "\n--- 2) Script invocation with positional arg ---"
try {
    & "$PSScriptRoot\..\Public\Get-CueAudit.ps1" $fixture -WhatIf
    Write-Output '-> Script with positional arg executed (no error).'
}
catch {
    Write-Output '-> Script with positional arg ERROR:'
    Write-Output $_.ToString()
}

# 3) Dot-source the script then call the exposed function
Write-Output "\n--- 3) Dot-source script then call function ---"
try {
    . "$PSScriptRoot\..\Public\Get-CueAudit.ps1"
    Get-CueAudit -Path $fixture -WhatIf
    Write-Output '-> Dot-sourced function call executed (no error).'
}
catch {
    Write-Output '-> Dot-source/function call ERROR:'
    Write-Output $_.ToString()
}

Write-Output "\n=== Test runner complete ==="
