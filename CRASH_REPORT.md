Crash report template — Pwsh native crash when running tests

Summary
-------
When the assistant spawns PowerShell 7 (pwsh) to run the project's Pester tests, pwsh repeatedly terminates with a native crash (exit code -1073741571). Running the same tests locally (manually) succeeds. Importing the module succeeds; the crash happens when the assistant runs tests that execute parts of `cleanCueFiles.ps1`.

Why this file
------------
Automated/test-runner environments may differ in subtle ways. This file collects repro steps, environment data, logs, and a ready-to-paste issue body you can file against the appropriate project (PowerShell repo, Pester, or PowerShell VS Code extension) depending on where investigation points.

Where to file
-------------
- If crash appears to be a PowerShell host/native issue: https://github.com/PowerShell/PowerShell/issues
- If crash seems tied to Pester test harness or Pester module invocation: https://github.com/pester/Pester/issues
- If crash is specific to VS Code extension spawning/terminal behavior: https://github.com/PowerShell/vscode-powershell/issues

Minimal reproduction steps (include in issue)
---------------------------------------------
1. Clone repository and ensure files are in place:
   - `cleanCueFiles.ps1`
   - `Tests\Analyze.Tests.ps1`
   - `CueFixer.psm1` (module loader)
2. Using PowerShell 7 (pwsh), run the tests in a spawned process as the assistant does:

   ```powershell
   pwsh -NoProfile -NoLogo -Command "Import-Module Pester -Force; Invoke-Pester -Script @{ Path = 'C:\Users\resto\Documents\PowerShell\Modules\CueFixer\Tests'; Output = 'Detailed' } ; exit $LASTEXITCODE"
   ```

3. Observe native crash (exit code -1073741571) when the assistant invokes the same command. Note: running `Invoke-Pester` directly interactively does not crash on this machine.

What I observed
----------------
- Minimal Pester tests (a tiny sanity Describe/It) do NOT crash.
- Dot-sourcing or importing the module is fine; crash occurs when certain test cases call into `cleanCueFiles.ps1` logic.
- Running the command locally in an external pwsh works for the user, but the assistant's spawned runs crashed frequently.
- When the assistant runs tests, crashes sometimes happen after long console output; saving output to file reduces crashes.

Required diagnostic data (attach to issue)
------------------------------------------
- Output of `pwsh -NoProfile -NoLogo -Command "$PSVersionTable | Out-String"`
- `Get-Module -ListAvailable Pester | Select Name,Version,Path | Out-String`
- The exact command that caused the crash (copy/paste)
- The `Detailed` Pester XML output (if any) or the `pester-detailed.txt` you captured
- Windows Application Event Log entries around the crash time (from `Get-WinEvent`) — include timestamps and error text
- If possible, a ProcDump capture (.dmp) of pwsh crashing (use Sysinternals procdump to capture)

Helpful commands to collect diagnostics
--------------------------------------
```powershell
# PowerShell info
pwsh -NoProfile -NoLogo -Command "$PSVersionTable | Out-String" > pwsh-version.txt

# Pester module info
pwsh -NoProfile -NoLogo -Command "Get-Module -ListAvailable Pester | Select Name,Version,Path | Out-String" > pester-versions.txt

# Run tests and capture output
pwsh -NoProfile -NoLogo -Command "Import-Module Pester -Force; Invoke-Pester -Script @{ Path = 'C:\Users\resto\Documents\PowerShell\Modules\CueFixer\Tests'; Output = 'Detailed' }" > pester-detailed.txt 2>&1

# Collect application event log entries for last 30 minutes
Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-30)} |
  Where-Object { $_.Message -match 'pwsh.exe' -or $_.Message -match 'PowerShell' } |
  Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List > eventlog.txt

# (Optional) Use procdump to capture a crash dump (run as admin)
# procdump -e -ma -w pwsh.exe C:\temp\pwsh-crash.dmp
```

Suggested issue body (copy/paste)
--------------------------------
Title: Native crash (exit code -1073741571) when assistant-spawned pwsh runs Pester tests

Body:
```
Environment:
- Windows 11 Home (build ...)
- PowerShell 7.x (pwsh) - see attached pwsh-version.txt
- Pester 5.7.1 - see attached pester-versions.txt

Repro steps:
1. Run the following command (assistant-spawned style):
   pwsh -NoProfile -NoLogo -Command "Import-Module Pester -Force; Invoke-Pester -Script @{ Path = '<path to Tests>'; Output = 'Detailed' } ; exit $LASTEXITCODE"
2. Observe pwsh terminates with exit code -1073741571.

Notes:
- Running the tests manually in an interactive pwsh session does NOT reproduce the crash on this machine.
- Minimal Pester tests do not crash; tests that call into `cleanCueFiles.ps1` logic trigger the crash.

Attachments provided:
- pwsh-version.txt
- pester-versions.txt
- pester-detailed.txt
- eventlog.txt
- (optional) pwsh-crash.dmp (proc dump)
```

Next steps
----------
- Review and attach the collected files above to the issue.
- File either on PowerShell, Pester, or vscode-powershell depending on initial findings. If unsure, start with the PowerShell repo and they can triage.

If you want, I can prepare these diagnostic files in the workspace (pwsh-version.txt, pester-versions.txt, pester-detailed.txt, eventlog.txt) for you to review and attach. Tell me to proceed and I'll create them (I will not run Invoke-Pester to avoid causing the crash here).
