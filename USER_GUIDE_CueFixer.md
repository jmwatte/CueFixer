# CueFixer - User Manual (Simple, friendly)
This short manual shows how a person with an audio library can check and clean up CUE files using the scripts in this repository.
## Quick checklist


## Viewing and saving audit results (recommended)

For large audits (hundreds of files) run the audit once and save the full results so you can triage without re-scanning your drive.


Commands (copy/paste):

1) Run the audit and write a CLIXML file (recommended):

```powershell
Get-CueAudit -Path 'D:\' -Recurse -OutFile 'C:\Temp\cue-audit-d-drive.clixml' -OutFormat clixml
```

2) Optional: create a CSV summary for quick browsing (CSV loses nested Fixes):

```powershell
Import-Clixml 'C:\Temp\cue-audit-d-drive.clixml' | Export-Csv 'C:\Temp\cue-audit-d-drive.csv' -NoTypeInformation
```

3) Re-open results and use the viewers (pass `-Verbose` to see detailed lines):

```powershell
$results = Import-Clixml 'C:\Temp\cue-audit-d-drive.clixml'

# Counts
$results | Show-AuditSummary -Verbose

# Proposed fixes (DryRun shows OLD/NEW proposals). Use -Verbose to see the fix text.
$results | Show-Fixable -DryRun -Verbose

# Manual/unfixable items
$results | Show-Unfixable -Verbose
```

### Quick viewers (tools/)

Two small helper scripts live in the `tools\` folder to make triage easier without re-scanning your drive:

- `tools\show-audit-summary.ps1` — prints grouped counts (Clean/Fixable/Unfixable), percentages, and optional samples per status.
	- Example (from saved CLIXML):

	```powershell
	Import-Clixml 'C:\Temp\cue-audit-d-drive.clixml' | .\tools\show-audit-summary.ps1 -ShowSamples -Sample 8
	```

- `tools\show-audit-diagnostic.ps1` — shows a detailed diagnostic for a single audit item (by Path or the first item of a given Status). Supports showing proposed Fixes and a preview of the cue file content.
	- Example: show the first Fixable item's diagnostic and include proposed fixes and a file preview:

	```powershell
	Import-Clixml 'C:\Temp\cue-audit-d-drive.clixml' | .\tools\show-audit-diagnostic.ps1 -FirstStatus Fixable -ShowFixes -ShowFileContent
	```

Commit note suggestion: these helpers were added on branch `chore/remove-ci-workflows` as convenience viewers for audit output.

4) If you only have the CSV and want counts or lists:

```powershell
# Counts
Import-Csv 'C:\Temp\cue-audit-d-drive.csv' | Show-AuditSummary -Verbose

# List unfixable paths
Import-Csv 'C:\Temp\cue-audit-d-drive.csv' | Where-Object { $_.Status -ieq 'Unfixable' } | Select-Object -ExpandProperty Path
```

5) Quick helper (included in `tools\`): `tools\show-audit-csv-summary.ps1` prints a JSON summary, grouped counts, and sample lists.

```powershell
.\tools\show-audit-csv-summary.ps1 -CsvPath 'C:\Temp\cue-audit-d-drive.csv' -Sample 10
```

Notes:
- Keep using `-Verbose` for detailed output — the viewers intentionally use `Write-Verbose` to follow PowerShell best practices and avoid linter issues.
- Avoid `Write-Host` in scripts; use structured output or `Write-Verbose` as shown above.
1. Make a full backup copy of your audio library folder (very important).
2. Open PowerShell (pwsh) and change directory to the folder where this project lives.
3. Import the module and list available commands to see what you can run.
4. Run an audit (dry-run) so you know what will change.
5. Run repairs (first as a dry-run/what-if; then apply for real when ready).
6. Spot-check a few CUE files and a few audio files with a player.
7. Remove temporary backups when you're satisfied.

## 1) Important preparation (do this first)

- Always make a backup copy of your audio library folder. Copy the whole music folder to an external drive, a different folder, or zip it.
- Work on a copy while you're learning. Don't operate on your only copy until you're confident.

Example (Windows File Explorer): right-click your music folder -> Copy, then Paste to another drive.

## 2) Open PowerShell and go to the project folder

- Start "PowerShell 7 (pwsh)". On Windows you can search "pwsh" or open PowerShell if pwsh is not available.
- Change to this repository directory (replace path if different):

```powershell
cd 'C:\Users\<yourname>\Documents\PowerShell\Modules\CueFixer'
```

## 3) Import the CueFixer module and see what's available

Importing the module makes the commands available in the session and is safe.

```powershell
Import-Module .\CueFixer.psm1 -Force
Get-Command -Module CueFixer
```

That will print the commands you can use, like: Get-CueAudit, Repair-CueFile, Show-AuditSummary, etc.

If you prefer to run the provided scripts directly, the `Public\` folder contains helpful wrapper scripts (you can run them as scripts).

## 4) Do an audit (dry-run) so you understand the problems

The goal of an audit is to find broken or inconsistent CUE files without changing your files yet.

- If there's a `Get-CueAudit` command or a `Public\Get-CueAudit.ps1` script, run it against your music folder in dry-run mode first. Example:

```powershell
# Example (replace with your music folder)
.\Public\Get-CueAudit.ps1 -Path 'D:\Music' -WhatIf

# If the script expects a positional argument instead of -Path, try:
.\Public\Get-CueAudit.ps1 'D:\Music'
```

- If the script or command supports `-WhatIf`, it will only show what it would change.
- If you don't know parameters, run `Get-Help` or read the top of the script file in `Public\`.

```powershell
Get-Help .\Public\Get-CueAudit.ps1 -Full
```

## 5) Fixing problems — use dry-run first, then apply

Common approach:

1. Run the repair script in "what-if" or dry-run mode to see proposed changes.
2. If you like the proposed changes, run the same command without `-WhatIf` to apply them.

Example:

```powershell
# Dry-run (replace with the repair script you have)
.\Public\Repair-CueFile.ps1 -Path 'D:\Music' -WhatIf

# If output looks good, run for real
.\Public\Repair-CueFile.ps1 -Path 'D:\Music'
```

Notes:
- The tools in this repository generally try to be conservative and keep backups. Look for `.bak` or similar files after a repair; keep them until you're sure.
- If a script does not accept `-WhatIf`, start by running it on a small sample folder (e.g., copy a small album folder and run it there).

## 6) Interactive fixes

There may be an interactive helper (`Run-InteractiveFix.ps1` or `Invoke-InteractiveFix`) that lets you confirm fixes one-by-one. This is the safest option for the first run.

```powershell
# Example interactive run
.\Public\Run-InteractiveFix.ps1 -Path 'D:\Music'
```

Follow the prompts. Choose to accept or reject suggested changes.

## 7) Verify a few files manually

- Open a few repaired CUE files in Notepad or VS Code. They are plain text — check that track titles and indexing look reasonable.
- Open the corresponding audio file in your player (VLC, Foobar2000) and see that the tracks load correctly.

## 8) Cleanup backups (only when you're happy)

- Many scripts create safe backups (for example `filename.cue.bak` or `filename.cue.preformat.*.orig`). If you're sure everything looks good, you can remove backups to save space.

PowerShell example to find backups:

```powershell
Get-ChildItem -Path 'D:\Music' -Include '*.bak','*.orig' -Recurse
```

Delete only when you are 100% sure.

## 9) If something goes wrong — quick troubleshooting

- If you see parse errors in a script, re-check that you are running PowerShell 7 (pwsh) and that the files are intact. Try: `pwsh -v`.
- If a script fails on a single file, copy that CUE file to a temporary folder and run the repair on just that file so you can debug safely.
- If a command is missing parameters, open the script in a text editor and read the header comment — many scripts include usage notes.

## 10) Tips for keeping a clean library

- Always keep one untouched backup of your library (external drive or cloud).
- Run audits regularly after adding new albums or ripping new files.
- Use the interactive mode until you trust automatic fixes.
- Use a consistent naming/ripping convention to reduce guesswork.

## 11) Packing up and publishing (optional)

If you want to move a working copy of your clean library into a simple GitHub repo later (no PRs, just a place to store files), a simple approach:

1. Make a fresh branch locally and clean out unnecessary `tools` and backups.
2. Create a ZIP of the cleaned music folder and push it as a release or add instructions in the new repo.

I can help you script this when you're ready.

---

If you'd like, I can also:
- Prepare a one-page checklist printable PDF.
- Create a small script that runs the audit then an interactive repair on a small sample folder automatically.

Saved file: `USER_GUIDE_CueFixer.md` (in repository root) — let me know if you want changes or a shorter/longer version.
