# P3-14 — App Privacy "Nutrition Label" Generation from Telemetry Catalog

**Epic:** E16 · **Primary package:** `Packages/Platform` (telemetry) · **Complexity:** S · **Priority:** Medium

## Goal
Produce accurate App Store Connect "App Privacy" questionnaire answers that are derived directly from the shipped telemetry/crash-reporting/licensing event catalog, so the label can never drift from what the code actually does.

## Background
Even though core document/vault processing is fully offline, the app has real, if opt-in and off-by-default, network paths: crash reporting, telemetry (P3-09's closed event-enum catalog), and license/update checks (P3-05/P3-06). The App Privacy questionnaire must reflect that these *can* transmit something when enabled — claiming blanket "Data Not Collected" would be inaccurate the moment a user opts in. Rather than have a human answer the questionnaire from memory of the design, this task ties the answers directly to the P3-09 event catalog (the actual enumerable source of truth) so they stay correct as that catalog evolves.

## Requirements
- Enumerate every network-capable path in the shipped app: telemetry event catalog (P3-09), crash reporting (P3-09), license validation (P3-05), update check (P3-06). For each, determine the closest matching App Store Connect "data type" category (e.g., "Diagnostics — Crash Data", "Diagnostics — Performance Data", "Identifiers — Device ID" for the rotatable install UUID) and whether it's linked to identity, used for tracking (expected: no — no cross-app/cross-site tracking exists), and collection is user-initiated/opt-in.
- Write a small script or doc-generation step that reads the telemetry event catalog and emits a draft App Store Connect answer sheet, so a future catalog change (new event type) produces a visible diff in the privacy-label draft instead of silent staleness.
- Cross-check against the Privacy Dashboard's (P3-03) own "what we send" surfaced text — the two must say the same thing to the user and to Apple.

## Dependencies
- P3-09 (telemetry event catalog exists), P3-03 (Privacy Dashboard exists, for cross-check consistency).

## Files Likely Affected
- `Scripts/generate-privacy-label.sh` or equivalent (new, reads `docs/specs/telemetry-catalog.md` or the catalog source directly)
- `docs/specs/app-privacy-label.md` (new — the draft answer sheet, kept current)

## Acceptance Criteria
- Draft App Store Connect answers exist for every data type actually collectible by the shipped app, with no category left blank or defaulted to "not collected" without justification.
- Privacy Dashboard copy and the drafted App Store label answers make identical claims about what is/isn't sent.
- Re-running the generator after a hypothetical new telemetry event addition produces a visibly changed draft (proving it isn't a one-time hand-written document masquerading as generated).

## Definition of Done
- Global DoD, plus: the draft answer sheet reviewed against the actual P3-09 catalog file diff-for-diff, not against a description of it.

## Testing Requirements
- A test addition of a dummy event to the catalog (in a scratch branch/throwaway, not merged) demonstrably changes the generated draft, confirming the generator is live, not static.

## Documentation Updates
- `docs/specs/app-privacy-label.md` (new); `docs/specs/telemetry-catalog.md` gains a note that it is the source of truth for this label.
