# P1-16 — Atomic Save, Versioned Backups & Crash Recovery

**Owner:** claude-agent · **Branch:** task/P1-16-atomic-save-clean

**Epic:** E2 · **Primary package:** `Packages/DocumentSession` (save path) + engine save in `DocEngineHost` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Status (2026-07-13 update #2)

**Done this iteration:** `NSFileCoordinator`-based coordination for the atomic replace (`FileCoordinating` protocol + `NSFileCoordinatorAdapter`, injected into `AtomicSaver`, default real coordinator, `Mock*` for tests). The backup capture and the `replaceItemAt` swap now both run inside one `coordinateReplace(of:.forReplacing)` call around `original`. Existing tests pass unmodified (regression proof); two new tests cover coordinator routing and coordination-failure abort-safety (same "original untouched, no backup written" contract as validation failure).

**Still not done (unchanged from below, next iteration's scope):**
- `DocEngineHost` engine-side save modes (full-rewrite/incremental) — unblocked now that P0-06 merged, not yet started.
- Crash-recovery journal (unsaved-changes journal, relaunch recovery offer) — not started.
- `Scripts/corpus-roundtrip.sh` release-gate suite — not started, still needs corpus per E-005.
- `docs/adr/ADR-011-save-path.md` (renumbered from the task's stale ADR-009 reference, see below) — not started.

## Status (2026-07-13 update #1)

**Blocker cleared:** P0-06 (render pipeline) merged (`tasks/done/P0-06-render-v1.md`, PR #57). The `DocEngineHost` engine-side save modes item below is no longer blocked — `tasks/escalations/E-008-p0-07-p1-16-documentsession-conflict.md` was filed before this merge landed and is stale; its "live conflict" framing no longer holds now that the blocking dependency is satisfied. Next agent to pick up this task should resume the remaining scope listed below rather than idling on it.

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

## Journal

### 2026-07-13 — resumed (this session)

Read: root `CLAUDE.md`, this task file, `Packages/DocumentSession/CLAUDE.md`,
`Packages/DocumentSession/Sources/DocumentSession/Save/AtomicSave.swift` +
its test file. Toolchain re-verified (`xcode-select -p` → Xcode 26.6,
`swift test` works) — E-001/E-002 are stale, confirmed cheaply per their
own "re-verify before trusting" note. `git log` confirms the atomic-replace
core already merged (`118131b`, PR #48); no stale local/remote branch
remained, so re-created `task/P1-16-atomic-save-clean` off fresh `main`.

Per this file's own 2026-07-13 status note (written by a prior iteration
of this same lineage) and `tasks/escalations/E-008-...md`'s "stale, resume
rather than idle" verdict, continuing this in-progress claim rather than
idling on phase-0 (whose only backlog task, P0-07, is still blocked on
this package).

**Plan for this slice** (one of the four remaining follow-ups — scoping to
one to keep the PR small per CLAUDE.md §2 "small, verifiable increments";
the other three — engine save modes, crash-recovery journal,
corpus-roundtrip.sh — stay open in Status above for the next iteration):
- Add `NSFileCoordinator`-based coordination around the atomic replace in
  `AtomicSave.swift`, so iCloud-Drive-resident originals get correct
  coordination (today's `FileManager.replaceItemAt` call is uncoordinated,
  which is the gap this task's Requirements line calls out).
- New `FileCoordinating` protocol + `NSFileCoordinatorAdapter` (real
  default) so the existing tests keep working unmodified (local files
  coordinate fine with no iCloud entitlement) and a `Mock*` coordinator can
  test the error path (coordination failure aborts before `original` is
  touched, same contract as validation failure).
- No engine/XPC/API package touched — stays inside `Packages/DocumentSession`,
  not `[INTEGRATION]` for this slice.
- Test strategy: existing `AtomicSaveTests` must still pass unmodified
  (regression proof default coordinator doesn't change behavior for plain
  local files); new tests for coordinated-write success and coordination-error
  abort-safety.
- Risk: NSFileCoordinator requires running with a registered file presenter
  in some contexts for full iCloud semantics — out of scope here (no
  `NSFilePresenter` in this session-less path); coordinating without one is
  still correct per Apple docs (presenter registration is for *receiving*
  notifications of others' changes, not required to *make* a coordinated
  write).
