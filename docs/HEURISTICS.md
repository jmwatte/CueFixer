HEURISTICS — Design and contract

Purpose
-------
This document defines the pluggable heuristics architecture for CueFixer. Heuristics determine whether a cue-file content issue (typically a FILE entry) is fixable and propose candidate fixes with confidence scores.

Contract (Heuristic function)
-----------------------------
Each heuristic is a PowerShell script exposing a function that accepts a single hashtable parameter and returns zero or more PSCustomObject candidate decisions.

Input (hashtable keys)
- CueFilePath: string — absolute path to the .cue file being analyzed
- CueLines: string[] — lines of the cue file
- CueFolderFiles: FileInfo[] — files present in the same folder as the cue file
- Context: hashtable — arbitrary data supplied by the analyzer (e.g., validAudioExts, module config)

Output: array of PSCustomObject candidates
Each element must contain at least the following properties:
- Type: 'Fix' | 'Ambiguous' | 'Unfixable' (string)
- OldLine: string — the original cue line this candidate addresses
- NewLine: string? — proposed replacement (for Fix or Ambiguous)
- Confidence: double (0.0 - 1.0) — higher is more confident
- Heuristic: string — heuristic name
- Reason: string — short human-readable reason

Error handling
- Heuristics should not throw for normal operational conditions. If they do, the HeuristicsEngine will treat errors as "no-op" and log details.

Integration points
- The analyzer (`Get-CueAuditCore`) will call the HeuristicsEngine with the inputs above.
- The HeuristicsEngine aggregates candidates from enabled heuristics, resolves conflicts using configured thresholds and weights, and returns the selected candidates to the analyzer.

Profiles & Configuration
- A configuration object (ModuleConfig or per-call overrides) will specify enabled heuristics, weights, and thresholds (Accept/Ask/Decline).
- Example profile: `@{ Heuristics = @('ExactName','ExtensionRecovery'); Weights = @{ ExactName=1.0; ExtensionRecovery=0.9 }; Thresholds = @{ Accept=0.9; Ask=0.6 } }`

Evaluation harness
- `tools/heuristic-eval.ps1` will run heuristics against a fixture corpus and generate CSV reports with metrics (TP/FP/FN/Ambiguous/time).

Privacy & Safety
- Fingerprint-based heuristics (AudioFingerprint) must be opt-in and documented due to higher CPU/IO cost and possible dependency on native libs.

Next steps
- Implement `Lib/Heuristics/Base.ps1` and `Lib/Heuristics/HeuristicsEngine.ps1` (stubs), add simple heuristics, and wire into `Get-CueAuditCore`.
- Create test fixtures under `Tests/Fixtures/heuristics` to evaluate heuristics.
