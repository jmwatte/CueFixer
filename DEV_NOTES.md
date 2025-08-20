# Developer Notes — Running Tests

Short note to avoid repeated crashes when running Pester from the assistant environment.

Summary
- Tests for this module run fine locally but invoking them from the assistant (which spawns pwsh) has repeatedly caused native crashes on this machine. To avoid that, run tests locally in your own pwsh session.

Environment
- PowerShell: PowerShell 7 (pwsh)
- Pester: 5.7.1

How to run tests locally (recommended)
1. Open your external PowerShell 7 (pwsh) — do not rely on the assistant or integrated VS Code terminal if you've seen crashes.
2. From the module root run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Script @{ Path = '.\Tests'; Output = 'Detailed' }
```

If a crash occurs locally, narrow it by running a single test file or a single `It` block and capture output to a file:

```powershell
# single file
Invoke-Pester -Script @{ Path = '.\Tests\Analyze.Tests.ps1'; Output = 'Summary' } > pester-summary.txt 2>&1

# single test (edit the file to comment others out) and re-run
```

Notes to contributors
- Do not ask the assistant to execute the full test suite on this workspace; instead ask it to edit/prepare tests and then run them locally. This avoids the pwsh crash observed when the assistant spawns processes here.

