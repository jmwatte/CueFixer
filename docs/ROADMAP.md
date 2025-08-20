## CueFixer Roadmap & To‑Do (short-lived tactical roadmap)

This file captures the prioritized roadmap and TODO items discussed during the heuristics/engine work so we don't lose the proposal.

Summary
- Goal: Make fix/repair decisions pluggable and testable via a heuristics engine. Heuristics must be conservative by default and measurable.
- Current state: engine scaffolding and two heuristics implemented on branch `feat/heuristics-stub`:
  - ExactNameMatch (high confidence)
  - ExtensionRecovery (high/ambiguous depending on candidates)

Priority tasks (short term)
1. Implement PreferredExtension heuristic
   - Purpose: pick a preferred audio extension when multiple candidates exist (e.g., prefer .flac over .mp3 if configured)
   - Acceptance: unit tests that cover unique preferred candidate and ambiguous sets
2. Implement FuzzyNameMatch heuristic
   - Purpose: use string-distance (Levenshtein or tokenized Jaro) to propose likely matches when exact match fails
   - Acceptance: produce candidates with lower confidence; add tests with edge cases (short names, numeric suffixes)
3. Improve HeuristicsEngine
   - Add profiles (conservative, balanced, aggressive)
   - Add weights/thresholds and conflict resolution rules (Accept/Ask/Reject)
   - Add ability to enable/disable heuristics per-run

Medium term
- Implement MetadataMatch (read audio tags) — opt-in due to dependency/runtime cost
- Add AudioFingerprint heuristic (heavy, optional external tool or service)
- Add detailed logging/metrics for each heuristic candidate (confidence, reason, time)

Evaluation & Testing
- Expand `tools/heuristic-eval.ps1` to run heuristics against a labeled corpus and emit CSV metrics (TP/FP/FN/Ambiguous, runtime)
- Add fixtures under `Tests/Fixtures/heuristics/` with positive/negative cases
- Add Pester tests for each heuristic (happy path + ambiguous + negative)

CI & Automation
- Add a CI job to run heuristic evaluation and upload CSV artifacts (optional, gated by branch or schedule)
- Keep PSScriptAnalyzer and Pester jobs in CI (already present in `.github/workflows/analysis.yml`)

Operational notes
- Heuristics must be conservative by default when `Repair-CueFile` runs non-interactively. Auto-apply only when aggregated confidence exceeds configured threshold.
- Provide a dry-run mode that shows proposed fixes and confidence scores.

Next steps (recommended immediate actions)
1. Add PreferredExtension and FuzzyNameMatch implementations and unit tests on `feat/heuristics-stub`.
2. Wire them into `Lib/Heuristics/HeuristicsEngine.ps1` and add profile/weight configuration in `Lib/ModuleConfig.ps1`.
3. Run Pester locally via `tools/run-pester.ps1` and push the updated branch, then open a draft PR to get CI feedback.

Status
- This roadmap file created from the latest design notes and the in-repo `docs/HEURISTICS.md` — see that file for more detail.

If you'd like, I can also open a draft PR for `feat/heuristics-stub` now, or implement the next heuristic (PreferredExtension) and push it first.
