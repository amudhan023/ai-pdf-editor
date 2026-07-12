# P1-16 — Atomic Save, Versioned Backups & Crash Recovery

**Owner:** claude-agent · **Branch:** task/P1-16-atomic-save-clean

**Epic:** E2 · **Primary package:** `Packages/DocumentSession` (save path) + engine save in `DocEngineHost` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Status (2026-07-11)

**Done:** the `Packages/DocumentSession` atomic-replace core — `AtomicSaver.replace(original:withTemp:)` using `FileManager.replaceItemAt` (verified: no window where the original file is missing or partially written, even across a crash), reopen-based validation via an injected `PDFEngineAPI.DocumentLifecycle`, and versioned/rotated backups. See `docs/ENGINEERING_AUDIT_2026-07-11.md` finding C-1 for the defect history this replaces (an earlier scaffold on a different, now-abandoned branch was not actually atomic and broke on a document's second save).

**Not done (blocked or follow-up):**
- `DocEngineHost` engine-side save modes (full-rewrite/incremental) — blocked on P0-06 (render pipeline), which doesn't exist yet; this task's own `Dependencies` line already names that blocker.
- `NSFileCoordinator`-based coordination for iCloud-Drive-resident files — not yet added; the current atomic-replace core works for local files, coordination is an additive follow-up, not a redesign.
- Crash-recovery journal (unsaved-changes journal, relaunch recovery offer) — not started.
- `Scripts/corpus-roundtrip.sh` release-gate suite — not started; needs a real corpus + engine to open documents with (same P0-06 blocker), per `tasks/escalations/E-005-corpus-acquisition-gap.md`.
- `docs/adr/ADR-009-save-path.md` — **note:** ADR-009 is already taken (`ADR-009-claude-md-agent-loop-self-merge.md`); this task's doc references the wrong number. If/when a save-path ADR is warranted, it should be `ADR-011` (ADR-001 was claimed by the PDFium sourcing decision, P0-03).

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
