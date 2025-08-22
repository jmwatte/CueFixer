<#
Lint script to detect non-PowerShell tokens embedded in .ps1 files that could break dot-sourcing or module loading.
Checks:
- Triple backtick fences (```) which are commonly from Markdown pasted into scripts.
- A small list of suspicious dot-prefixed tokens (e.g., .DESCRIPTION) that have caused problems.

Exits with code 0 when no issues found, otherwise exits 1 and prints offending files/lines.
#>

$ErrorActionPreference = 'Stop'

$root = Split-Path -Path $PSScriptRoot -Parent
Write-Host "Scanning repository at: $root"

# Files to scan (exclude third-party directories if any)
$files = Get-ChildItem -Path $root -Recurse -Include '*.ps1','*.psm1' -File |
    Where-Object { $_.FullName -notmatch '\\bin\\|\\obj\\|\\.git\\' }

$issues = @()

foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    # Track whether we're inside a block comment (<# ... #>) so legitimate
    # comment-based help (which uses .DESCRIPTION and similar tokens) is ignored.
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Toggle block comment state when encountering start/end markers.
        if ($line -match '<#') { $inBlockComment = $true }
        if ($line -match '#>') { $inBlockComment = $false; continue }

        # If we're not inside a block comment, perform the checks. This prevents
        # flagging normal <# .DESCRIPTION ... #> help blocks.
        if (-not $inBlockComment) {
            if ($line -match '```') {
                $issues += [PSCustomObject]@{
                    File = $f.FullName
                    Line = $i + 1
                    Problem = "Triple-backtick fence found (outside a block comment)"
                    Text = $line.Trim()
                }
            }

            # Common stray token we observed: a bare ".DESCRIPTION" line
            if ($line -match '^[ \t]*\.DESCRIPTION\b') {
                $issues += [PSCustomObject]@{
                    File = $f.FullName
                    Line = $i + 1
                    Problem = "Stray token '.DESCRIPTION' found (outside a block comment)"
                    Text = $line.Trim()
                }
            }

            # Catch other dot-prefixed bare words that look suspicious (e.g., ".FOO")
            if ($line -match '^[ \t]*\.[A-Z]{3,}($|\s)') {
                $issues += [PSCustomObject]@{
                    File = $f.FullName
                    Line = $i + 1
                    Problem = "Suspicious dot-prefixed token (outside a block comment)"
                    Text = $line.Trim()
                }
            }
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Host "No suspicious non-PS tokens found." -ForegroundColor Green
    exit 0
}

Write-Host "Found suspicious tokens in scripts:" -ForegroundColor Yellow
$issues | Format-Table -AutoSize

Write-Host "Failing lint to prevent merge; please remove embedded Markdown fences or stray tokens from .ps1/.psm1 files." -ForegroundColor Red
exit 1



