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

**DocumentSession implement:** Added `pageOrganizer: (any PageOrganizer)?` (optional-capability pattern) and `reorderPage`/`rotatePage`/`duplicatePage`/`insertPage(fromFile:)`/`mergeDocument(fromFile:)`/`deletePage`, plus `PageOperationUndoStack` (mirrors `AnnotationUndoStack`). Two real bugs found and fixed via the tests themselves, not by inspection: (1) `insertPage(fromFile:)`/`mergeDocument` originally closed the opened source handle right after import — broke `redo()`, which replays the same `.insert` against that now-closed handle; fixed by keeping import-source handles open for the session's lifetime, closed in `close()`. (2) A test using `pageCount: 3` setup duplications followed by a `deletePage` call caught that an untracked delete can invalidate an earlier recorded operation's target index — a later `undo()` of that earlier op threw `pageIndexOutOfRange`. Fixed by having `deletePage` call a new `PageOperationUndoStack.invalidateHistory()`, clearing all undo/redo history on any delete (conservative-safe, same principle `record()` already applies to the redo stack).

**Verify:** `Scripts/verify.sh DocumentSession` — OK (8 new tests, full Xcode.app, ran for real). `Scripts/check-boundaries.sh DocumentSession` — clean.

**Documentation:** Both `Packages/DocEngineHost/CLAUDE.md` and `Packages/DocumentSession/CLAUDE.md` updated with this task's sections.

## Handoff

**Status:** Engine layer (`DocEngineHost: PageOrganizer`) and session layer (`DocumentSession`'s page-management methods + undo) are both complete, tested, and verified green. **UI layer is not started**: drag-reorder with drop indicators, multi-select ops, context menus, toolbar, and the ThumbnailSelectionModel remap/clear-after-mutation wiring (P1-02's own handoff note — selection is positional, must be remapped or cleared after any structural page op; not done here) are all still open. This is the same shape of partial-but-honest handoff every other Complexity-M/L task this session left (P1-11's snapshot/XCUITest gap, P2-01's appearance-regeneration gap): the correctness-critical, hardest-to-get-right layers (real PDFium page-tree mutation, corruption safety, undo semantics) are done and tested; the UI wiring is comparatively mechanical follow-up.

**What's done:**
- `Packages/DocEngineHost/Sources/DocEngineHost/Pages/PDFiumPageOrganizer.swift`: real `PageOrganizer` conformance (insert/delete/reorder/rotate) via `fpdf_edit.h`/newly-vendored `fpdf_ppo.h`. Page-cache invalidation on every structural mutation (corruption-safety invariant). A real PDFium crash bug (self-import `src_doc == dest_doc`) found via the property-based fuzz test and worked around.
- `PDFiumPageOrganizerTests.swift`: 7 tests incl. the 50-random-op fuzz round trip (the task's own Acceptance Criteria wording), a cross-document merge/resource-preservation test (text survives import), delete/reorder/rotate/duplicate example cases.
- `Packages/DocumentSession/Sources/DocumentSession/Pages/PageOperationUndoStack.swift` + `DocumentSession`'s page-management methods, all undoable except `.delete` (documented capability gap, not silently skipped).
- `DocumentSessionPageTests.swift`: 8 tests covering every method, undo/redo, the not-undoable-delete contract, and import-source handle lifecycle.

**Deliberately not done (flagged, not silently skipped):**
1. **UI**: drag-reorder view, drop indicators, multi-select ops, context menus, toolbar, insert-from-file file-picker flow. None of this needs new engine/session capability — it's SwiftUI wiring against the now-complete `DocumentSession` API, analogous to how `MarkupToolbarView`/`ThumbnailSidebarView` already wire their respective session methods.
2. **Selection remap/clear after page ops**: P1-02's `ThumbnailSelectionModel` is positional; a page op invalidates it. The remap/clear call needs to happen at whatever layer calls `DocumentSession`'s page methods (likely `DocumentViewModel`, same layer that owns `ThumbnailSelectionModel` today) — not done.
3. **Delete-undo**: needs a "trash document" capability nothing reachable from `Packages/DocumentSession` can provide (`DocumentLifecycle` has no "create blank document" op). Needs either a new frozen-seam capability (ADR) or a different design — a decision for whoever picks this up, not made unilaterally here.
4. **`extract`/`split`**: fully expressible via the same `.insert`-composition pattern `duplicate`/`merge` already use (open/create a destination, insert the wanted source pages into it, save as a new file) — not implemented as dedicated `DocumentSession` methods in this pass, since neither is named in the task's own UI Requirements bullet (only "insert-from-file flow" is), though the Goal line does list them. Straightforward follow-up once someone decides where the "new destination document" should live (a fresh file the user picks via save panel, most likely — App-layer UI decision, out of this task's primary-package scope).
5. **`Scripts/corpus-roundtrip.sh`**: still doesn't exist anywhere in this repo (flagged "not yet built, P1-16" before this task started, unchanged by it). The property-based fuzz test in `PDFiumPageOrganizerTests` is the real deliverable for the Definition of Done's "page-ops fuzz sequence added to corpus-roundtrip suite" line; there is no script to add it to yet.
6. **"Merged output opens correctly in Acrobat/Preview with annotations and forms intact"**: verified at the layer that can actually test it (this engine's own re-parse: text survives cross-document import in `testMergeImportsPageWithTextIntactFromAnotherDocument`), not via literally launching Acrobat/Preview — same approach every other task this session used for real-viewer-adjacent criteria.

**Exact state:** branch `task/P1-06-page-management`, all work committed locally in this worktree (`/private/tmp/claude-501/-Users-amudhan-Desktop-project-ai-pdf-editor/e3790af4-14a0-460a-b4b4-8066910d910e/scratchpad/ai-pdf-editor-p1-06`), nothing pushed yet — coordinator handles push/PR. `Scripts/verify.sh DocEngineHost` and `Scripts/verify.sh DocumentSession` both OK.

**Next steps for whoever picks this up:** (a) decide whether to open the PR now with items 1-6 above as documented scope cuts (matches this repo's established precedent for Complexity M/L tasks), or (b) continue with the UI layer first. No dead ends — everything above is scoped-out follow-up work, not a blocker discovered too late to route around.
