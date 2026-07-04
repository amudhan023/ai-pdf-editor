# P1-16 — Atomic Save, Versioned Backups & Crash Recovery

**Epic:** E2 · **Primary package:** `Packages/DocumentSession` (save path) + engine save in `DocEngineHost` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
The never-corrupt save path (NFR-R2): write-to-temp → re-parse validation → atomic replace → versioned backup; incremental-update saves where supported; crash-recovery journal.

## Background
ARCHITECTURE.md §8.4 and driver 5. Every mutating feature (annotations, pages, forms, editing) funnels through this — it must land before P1-06 and the Phase 2 mutation tasks integrate.

## Requirements
- Engine: full-rewrite and incremental-update save modes; save validation = reopen + structural check before replace.
- DocumentSession: atomic replace via file coordination (NSFileCoordinator; iCloud-Drive-resident files behave); rolling versioned backups in container (opt-out setting), restore UI hook.
- Crash recovery: unsaved-changes journal; on relaunch, offer recovery.
- `Scripts/corpus-roundtrip.sh`: open→mutate→save→reopen over corpus; this becomes the release-gate suite.

## Dependencies
- P0-06.

## Files Likely Affected
- `Packages/DocumentSession/Sources/Save/**`; `Packages/DocEngineHost/Sources/Save/**`; `Scripts/corpus-roundtrip.sh`.

## Acceptance Criteria
- Kill -9 during save never leaves a corrupt or missing original (fault-injection test).
- Round-trip suite: zero corruption on corpus v1; validation failure aborts replace and surfaces error with original intact.

## Definition of Done
- Global DoD, plus: round-trip suite wired into bench.yml as a release gate.

## Testing Requirements
- Fault-injection matrix (kill points across the save sequence); incremental-vs-full equivalence checks; backup rotation tests.

## Documentation Updates
- docs/adr/ADR-009-save-path.md.
