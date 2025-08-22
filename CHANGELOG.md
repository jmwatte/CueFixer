# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2025-08-21
- Breaking: Removed plural public command `Invoke-ApplyFixes` and made `Invoke-ApplyFix` the canonical public API.
  - Migration: replace calls to `Invoke-ApplyFixes` with `Invoke-ApplyFix`.
  - Quick replace (PowerShell):

    ```powershell
    Get-ChildItem -Path . -Include *.ps1,*.psm1 -Recurse | ForEach-Object {
      (Get-Content -Raw -LiteralPath $_.FullName) -replace 'Invoke-ApplyFixes', 'Invoke-ApplyFix' | Set-Content -LiteralPath $_.FullName -Encoding UTF8
    }
    ```

  - Reason: align public cmdlet nouns with PowerShell guidelines (singular nouns) and simplify the public surface during active development.
