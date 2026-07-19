# P1-21 — DocEngineHost: Engine-Side Save Modes (`FPDF_SaveAsCopy`)

**Epic:** E2 · **Primary package:** `Packages/DocEngineHost` · **Complexity:** M · **Priority:** Critical

**Owner:** claude-agent · **Branch:** task/P1-21-docengine-save-modes · **Claimed:** 1908050d4465fa3ff45b8aeb999bf5074be8c059

## Goal
`PDFiumEngine.save(_:mode:to:)` actually serializes the open document's current state (including any in-memory mutations — annotations, page ops, form values) to bytes instead of throwing `unsupportedFeature("engineSaveNotYetImplemented")`, so `DocumentSession`'s atomic-save path (P1-16) has something real to write.

## Background
P1-16 (`tasks/done/P1-16-atomic-save-backups.md`) delivered the file-level write-temp → validate → atomic-replace mechanics but explicitly left "`DocEngineHost` engine-side save modes" undone, and no task tracked that remaining scope — discovered as a hard blocker by P1-04 (`tasks/escalations/E-009-p1-04-engine-save-missing.md`) when annotation CRUD had no way to reach disk. Every Phase 1/2 mutation feature (annotations P1-04/P1-05, page ops P1-06, form fill, text edit) shares this same blocker: none of their mutations can be persisted until this lands. `fpdf_save.h`'s `FPDF_SaveAsCopy`/`FPDF_SaveWithVersion` are the PDFium entry points; not yet declared in `CPDFium`'s header surface (same incremental-header pattern as `fpdf_annot.h`/`fpdf_doc.h`).

## Requirements
- Add `fpdf_save.h` to `CPDFium`'s module map; implement a `FPDF_FILEWRITE`-conforming Swift shim (callback-based streaming write, per PDFium's C API) so `FPDF_SaveAsCopy` can write into an in-memory buffer or file handle without needing PDFium to know about Swift `Data`/`URL` types directly.
- `PDFiumEngine.save(_:mode:to:)`: `.fullRewrite` via `FPDF_SaveAsCopy` (`FPDF_NO_INCREMENTAL` flag); `.incremental` via the default incremental-append flag — both must round-trip (open → save → reopen → structural check) against the existing PDFium test documents.
- Typed error surfacing on PDFium save failure (mirror `mapPDFiumError()`'s existing pattern) — never silently no-op.

## Dependencies
- P0-06 (done).

## Files Likely Affected
- `Packages/DocEngineHost/Sources/CPDFium/include/**`; `Packages/DocEngineHost/Sources/DocEngineHost/PDFiumEngine.swift`.

## Acceptance Criteria
- `PDFiumEngine.save` round-trips a mutated in-memory document (e.g. an added annotation) to a file that reopens with the mutation intact, for both `.fullRewrite` and `.incremental` modes.
- `DocumentSession`'s `AtomicSaver` can be wired to this instead of throwing, with a regression test proving a full open→mutate→save→reopen cycle through the real (not fake) engine.

## Definition of Done
- Global DoD, plus: unblocks the annotation/page-ops/form-fill file-persistence gaps tracked in `E-009` and equivalent notes in P1-05/P1-06/P2-xx tasks.

## Testing Requirements
- Fault-injection is P1-16's `Scripts/corpus-roundtrip.sh` concern (still separately blocked on fixture corpus per `E-005`); this task's own tests are engine-level open→mutate→save→reopen round-trips against the starter corpus.

## Documentation Updates
- `Packages/DocEngineHost/CLAUDE.md` — update the "save always throws unsupportedFeature" gotcha once this lands.
