# P1-06 — Page Management Operations

**Epic:** E5 · **Primary package:** `Packages/DocEngineHost` (page ops) + `DocumentSession` (thumbnail interactions) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Reorder (drag in thumbnails), rotate, insert (blank/from file), delete, duplicate, extract, split, and merge PDFs — all undoable, all corruption-safe.

## Background
PRD FR-1.5. Implements `PageOrganizer` from PDFEngineAPI; UI rides the P1-02 thumbnail selection model. Save-path integrity depends on P1-16 (atomic save) — page ops must go through it.

**P1-02 handoff (read before designing drag-reorder):** the selection model is `Packages/DocumentSession/Sources/DocumentSession/Sidebar/ThumbnailSelectionModel.swift` — selection identity is *positional* (`PageIndex`), documented on the type. After any reorder/insert/delete you must remap or `clear()` the selection; if selection needs to survive reorder visually, introduce a stable per-page identity at the engine seam (that's a frozen-seam/ADR change — budget for it). Sidebar click/⌘/⇧ dispatch happens in `ThumbnailSidebarView.handleTap`; navigation uses `DocumentViewModel.navigate(to:)`.

## Requirements
- Engine: page-tree manipulation incl. cross-document page import (fonts/resources carried correctly); merge/split as document-level ops.
- UI: drag-reorder with drop indicators, multi-select ops, context menus, toolbar; insert-from-file flow.
- Every operation on the DocumentSession undo stack.

## Dependencies
- P1-02, P1-16.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/DocEngineHost/` (PDFiumEngine + a `PageOrganizer` conformance; add `fpdf_ppo.h`/page-tree headers to `CPDFium` incrementally); `Packages/DocumentSession/Sources/DocumentSession/Sidebar/`.

## Acceptance Criteria
- Round-trip suite: any sequence of 50 random page ops → save → reopen → structure matches expectation, zero corruption on corpus sample.
- Merged output opens correctly in Acrobat/Preview with annotations and forms intact.

## Definition of Done
- Global DoD, plus: page-ops fuzz sequence added to corpus-roundtrip suite.

## Testing Requirements
- Property-based op-sequence tests; resource-preservation tests (fonts, links) on merge/extract.

## Documentation Updates
- None beyond package CLAUDE.md files.

## Journal

**Orient:** Root CLAUDE.md; `Packages/DocEngineHost/CLAUDE.md`; `Packages/DocumentSession/CLAUDE.md`; `PDFEngineAPI.PageOrganizer`/`PageOperation` (frozen, already has exactly `insert(from:sourcePage:at:)`/`delete`/`reorder`/`rotate`) and `FakePDFEngine`'s existing conformance (the reference implementation for correct clamping/error semantics). Read `AnnotationUndoStack` (P1-04) as the established undo-stack pattern to mirror. Read P1-02's handoff note in this task file: `ThumbnailSelectionModel` selection is positional, must be remapped/cleared after any structural page op.

**Plan:** No frozen-seam gap — `PageOperation` already composes duplicate (self `.insert`)/extract/split/merge (destination-doc `.insert` loops) without needing a new case. `Packages/DocEngineHost/Sources/DocEngineHost/Pages/PDFiumPageOrganizer.swift`: `PDFiumEngine: PageOrganizer` via `fpdf_edit.h`'s `FPDF_MovePages`/`FPDFPage_Delete`/`FPDFPage_SetRotation` (all already vendored) and `fpdf_ppo.h`'s `FPDF_ImportPagesByIndex` (not yet vendored — copied byte-identical from `ThirdParty/pdfium`'s pinned prebuilt headers, same technique every prior header-vendoring task this session used). Every structural op (insert/delete/reorder) must close and clear `OpenDocument.pages`' cached `FPDF_PAGE` handles first, since that cache is keyed by index and any structural change invalidates the mapping — added `PDFiumEngine.invalidatePageCache` for this.

**Implement + a real corruption bug found and fixed:** Wrote the conformance, wrote a property-based fuzz test (`PDFiumPageOrganizerTests.testFiftyRandomPageOpsRoundTripMatchesModelWithZeroCorruption` — 50 seeded-random ops against a synthetic 8-page document with per-page identity via distinct widths, mirrored against a plain-Swift model) per the task's own Acceptance Criteria wording. The fuzz test **crashed the test process (SIGTRAP)** on its first run — bisected via stderr-logged op traces (stdout buffering hid the crash location at first) to `FPDF_ImportPagesByIndex` called with `src_doc == dest_doc` (the self-duplicate case: `.insert(from: document, ...)` where `from == document`). This vendored PDFium build does not support same-pointer src/dest for that call — not documented either way in the header, discovered empirically, exactly what the fuzz test exists to catch. Fixed by snapshotting the destination document to an independent in-memory copy (`FPDF_SaveAsCopy` + `FPDF_LoadMemDocument64`) and importing from that instead, so PDFium never sees `src_doc == dest_doc`. Documented prominently in `PDFiumPageOrganizer.swift`'s header doc and the `.insert` case itself so nobody "simplifies" this back to the crashing form later.

Second bug found by the same fuzz test (a real test-design bug, not a product bug): the test's per-page "identity" was raw `metadata.size.width`, but `FPDF_GetPageWidth`'s own doc comment says rotation changes the returned value (90°/270° legitimately swap width/height) — correct engine behavior my naive model didn't account for. Fixed by comparing the unordered `{width, height}` pair instead of `width` alone (still a unique per-page identity, since every synthetic page shares the same base height but has a distinct base width).

**Verify:** `Scripts/verify.sh DocEngineHost` — OK (7 new tests incl. the fuzz test, full Xcode.app, ran for real).

**Harden notes:** `invalidatePageCache` is called unconditionally at the top of every structural-mutation branch, before the PDFium call that could fail — so even a failed `apply()` leaves no stale cached handles rather than leaving the cache correct-but-now-untrustworthy only on success. `.delete` additionally guards `count > 1` (refuses to leave a zero-page document) — not in the frozen `FakePDFEngine` reference implementation, added here because a real zero-page PDF is arguably a corrupt/degenerate document this engine shouldn't be able to produce; flagged in case a future task decides the fake should match. Security/privacy self-audit: touches document structure/bytes only, no vault content; no new logging.

**Handoff (DocumentSession half not yet started as of this Journal entry — continuing):** Engine layer (`DocEngineHost`) is complete and tested. Still to do per the task's Requirements: `DocumentSession`-level undo-stack wiring (mirror `AnnotationUndoStack`'s shape), session methods composing `duplicate`/`extract`/`split`/`merge` from `PageOperation.insert`, selection remap/clear per P1-02's handoff note, and the UI layer (drag-reorder, multi-select ops, context menus, toolbar, insert-from-file flow). `Scripts/corpus-roundtrip.sh` (Definition of Done's "add to corpus-roundtrip suite") still does not exist in this repo as of this task (root CLAUDE.md's Quick Reference Card already flagged it "not yet built, P1-16" before this task started) — the property-based fuzz test above is the real deliverable for that DoD line; noting the still-missing script here so it isn't silently lost, same class of honest gap P1-22/P2-01 both flagged for their own DoD lines.
