# CueFixer — Modularization What‑If

[![CI](https://github.com/jmwatte/CueFixer/actions/workflows/pester.yml/badge.svg?branch=main)](https://github.com/jmwatte/CueFixer/actions/workflows/pester.yml)

<!-- Replace <OWNER>/<REPO> above with your GitHub repository path to activate the badge -->

This document captures a what‑if modularization plan for the existing `cleanCueFiles.ps1` script. It is a conceptual design and migration recipe only — no code changes are made here.

## Quick checklist
- [x] Read the current `cleanCueFiles.ps1` and extract responsibilities
- [x] Propose a file/folder layout for a modular module
- [x] Define public API (cmdlet surface) and contracts
- [x] List edge cases and tests to cover
- [x] Provide a short migration recipe and next steps

## High level goals
- Separate pure logic from IO and UI
- Make core functions pure and unit-testable (no direct disk writes)
- Provide small, composable public cmdlets supporting pipeline and dry-run
- Add tests (Pester) and linting (PSScriptAnalyzer)

## Proposed folder layout
CueFixer/
- `CueFixer.psm1` — module loader/wiring (dot-source libs and export public functions)
- `CueFixer.psd1` — module manifest (existing)
- `Public/` — thin cmdlet wrappers (parameter binding, pipeline support)
	- `Get-CueAudit.ps1`
	- `Repair-CueFile.ps1`
	- `Invoke-CueInteractive.ps1`
- `Lib/` — pure, side-effect-free logic
	- `Analyze.ps1`            # analyze cue content, returns objects
	- `StructureFixer.ps1`     # reconstructs correct cue structure
	- `ContentFixer.ps1`       # computes content fixes (FILE lines, indexes)
	- `Models.ps1`             # factories / recurring PSCustomObject shapes
- `IO/` — controlled disk and editor operations
	- `FileIO.ps1`             # read/write, backup, encoding detection/preservation
	- `Editor.ps1`             # Open-InEditor abstraction
- `UI/` — output and interactive flows
	- `Interactive.ps1`        # Invoke-InteractiveFix
	- `Reporting.ps1`         # Show-Fixables/Show-Unfixables/Summaries
- `Tests/` — Pester tests

## Public API (recommended)
- `Get-CueAudit [-Path] [-Recurse] [-Filter]` — returns objects: Path, Status (Clean|Fixable|Unfixable), Fixes, UpdatedLines, NeedsStructureFix, StructureErrors
- `Repair-CueFile [-Path] [-Backup] [-DryRun] [-Force]` — accepts pipeline input; performs backups and writes changes unless DryRun
- `Invoke-CueInteractive [-Path] [-Editor]` — interactive flow wrapper

Design notes: return objects, avoid direct Write-Host in lib code. Surface `-WhatIf`/`-Confirm`/`-Verbose` for destructive ops.

## Contracts (short)
- Analyze (pure): input = string path or string[] content; output = PSCustomObject with fields listed above; does not write files.
- Apply-Fixes: input = analysis result(s) + options; output = per-file result (Before/After/BackupPath); honors DryRun and returns non-zero on unrecoverable errors.

## Important edge cases to test
- TRACK before FILE or INDEX outside TRACK (structure fixable)
- FILE line missing extension with multiple candidate audio files (ambiguous)
- Missing referenced audio file (unfixable)
- Mixed-case extensions and extra whitespace
- CRLF vs LF and UTF BOM preservation

## Testing & quality gates
- Unit tests (Pester) for `Lib/*` functions: happy path + 1–2 edge cases each
- Lint with PSScriptAnalyzer and fix major rules
- Smoke test: import the module, run `Get-CueAudit -Path <sample>` and `Repair-CueFile -DryRun`

## Migration recipe (safe, incremental)
1. Create the folder layout above. Start with `Lib/Analyze.ps1` and copy the `Analyze-CueFile` logic, modifying it to return objects and not touch disk. Add Pester tests for it.
2. Add `IO/FileIO.ps1` that centralizes Get-Content/Set-Content/backup logic. Keep `FileIO` usage limited to `Public/*` wrappers.
3. Extract `Fix-CueFileStructure` into `Lib/StructureFixer.ps1` and write tests verifying idempotence.
4. Implement `Public/Get-CueAudit.ps1` and `Public/Repair-CueFile.ps1` that call `Lib/*` and `IO/*` and honor `-DryRun` and `-WhatIf`.
5. Wire `CueFixer.psm1` to dot-source the scripts and export the public functions.
6. Run Pester and PSScriptAnalyzer; iterate until green.

## Usage

The module exposes small, composable cmdlets you can call directly from PowerShell or wire into scripts.

Examples:

- Import the module (when working from the repo root):

	```powershell
	Import-Module .\CueFixer.psm1 -Force -Verbose
	```

- Audit a single CUE file and show the full object:

	```powershell
	Get-CueAudit -Path '.\album\album.cue' | Format-List -Property *
	```

- Audit a directory recursively:

	```powershell
	Get-CueAudit -Path 'C:\Music' -Recurse
	```

- Dry-run a repair (no files written):

	```powershell
	Get-CueAudit -Path .\album | Repair-CueFile -DryRun -Verbose
	```

- Repair and create a backup (writes changes):

	```powershell
	Get-CueAudit -Path .\album | Repair-CueFile -Backup
	```

- Use `-WhatIf`/`-Confirm` to preview destructive operations:

	```powershell
	Repair-CueFile -Path .\album\album.cue -WhatIf
	```

- View command help (full examples and parameter details):

	```powershell
	Get-Help Get-CueAudit -Full
	```

Try it (copy/paste):

```powershell
# from the repo root
Import-Module .\CueFixer.psm1 -Force

# audit and dry-run repair
Get-CueAudit -Path .\Tests\Fixtures -Recurse | Repair-CueFile -DryRun
```

If you'd like, I can add a short sample fixture under `Tests/Fixtures/` and a small `examples/` folder with before/after cue files to make these examples reproducible.

## Next steps I can take (pick one)
- Scaffold the module layout and create `Lib/Analyze.ps1` plus unit tests (recommended first step)
- Create `CueFixer.psm1` wiring and export small public wrappers
- Add a Pester test harness and a CI-friendly `psake`/`task` to run tests and analyzers

---
This README is intentionally prescriptive but not prescriptive about implementation details. If you'd like, I can scaffold the repository changes now (create files and a first unit test).

## Suggestions to Enhance or Extend
1. Add Logging Abstraction

	Consider adding a `Log.ps1` in `UI/` or `IO/` to centralize verbose/debug output. This lets you toggle verbosity or redirect logs without polluting logic. Example:

	```powershell
	function Write-Log {
		 param (
			  [string]$Message,
			  [string]$Level = 'Info'
		 )
		 if ($Level -eq 'Verbose') { Write-Verbose $Message }
		 elseif ($Level -eq 'Debug') { Write-Debug $Message }
		 else { Write-Host $Message }
	}
	```

2. Add a `Validate-CueFile.ps1`

	Before analyzing or repairing, provide a validation step that checks encoding, basic structure, and referenced file existence. This can live in `Lib/` (pure validation) or `Public/` (used as a pre-check).

3. Consider a `CueFixer.json` config

	Support user-defined rules (preferred audio extensions, backup folder, verbosity) by loading a JSON config from project root or user profile via `IO/FileIO.ps1`.

4. Add a `New-CueFixReport.ps1`

	In `UI/Reporting.ps1`, generate human-readable summaries and export options (CSV/HTML/JSON) for batch audits.

🧪 Testing Strategy Add-ons

- Golden files: store sample cue files in `Tests/Fixtures/` and compare analyzer output against expected results.
- Mutation tests: deliberately corrupt cue files and verify `Analyze.ps1` flags issues correctly.
- CI Integration: add GitHub Actions or Azure DevOps pipelines to run Pester + PSScriptAnalyzer on push.

If you want, I can scaffold any of the above (log abstraction, validation, config loader, reporter, or test fixtures). Which one shall I create first?
