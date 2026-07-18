# P1-04 — Annotations: Text Markup Set

**Owner:** claude-agent · **Branch:** task/P1-04-annotations-markup · **Claimed:** b900e1e30213a435a59ecad9bef49fbb85229e52

**Epic:** E4 · **Primary package:** `Packages/DocEngineHost` (annotation store) + `DocumentSession` (tools) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Highlight, underline, strikeout, squiggly — selection-driven creation, spec-compliant storage, edit/delete, Acrobat/Preview interoperable.

## Background
PRD FR-1.3 demands standard annotation objects for round-trip interop (NFR-C2). Uses P1-03 text geometry for selection quads.

## Requirements
- Engine: create/read/update/delete text-markup annotations (quad points, color, opacity, author, dates) persisted per PDF spec.
- UI: text selection → markup toolbar; color swatches; click-to-select existing markup; delete.
- Round-trip: annotations created in Acrobat/Preview render and edit correctly, and vice versa.

## Dependencies
- P1-03.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Annotations/**`; `Packages/DocumentSession/Sources/Annotate/**`.

## Acceptance Criteria
- Round-trip fixture suite (files annotated by Acrobat/Preview) passes both directions.
- Undo/redo works through DocumentSession's undo stack.

## Definition of Done
- Global DoD, plus: interop fixtures added to corpus manifest.

## Testing Requirements
- Serialization tests against PDF-spec expectations; snapshot tests for rendering; undo-stack unit tests.

## Documentation Updates
- None beyond package CLAUDE.md files.

## Journal

**Orient:** Read root CLAUDE.md, this task file, `Packages/DocEngineHost/CLAUDE.md`,
`Packages/DocumentSession/CLAUDE.md`, `Packages/PDFEngineAPI/CLAUDE.md` +
`okf/packages/pdf-engine-api.md`. Found:
- `PDFEngineAPI.Annotation`/`AnnotationStore` protocol already exist (frozen
  seam v1, ADR-006) but `Annotation` only carries a single `boundingBox` —
  no quad points (plural line-segment quads needed for multi-line
  highlight/underline/strikeout/squiggly per ISO 32000-1 §12.5.6.2), no
  separate opacity, no `createdAt`. `FakePDFEngine` + `PDFEngineConformanceSuite.verifyAnnotationStore`
  already implement/exercise the existing shape; `DocEngineHost.PDFiumEngine`
  does **not** implement `AnnotationStore` at all yet (confirmed via grep).
  `ThirdParty/pdfium`'s vendored xcframework already ships `fpdf_annot.h`
  with everything needed (`FPDFPage_CreateAnnot`, `FPDFAnnot_Set/GetColor`,
  `FPDFAnnot_*AttachmentPoints` for quad points, `FPDFAnnot_Set/GetStringValue`
  for author/contents) — just not yet exposed through `CPDFium`'s module map.
- **Hard blocker discovered:** `PDFiumEngine.save(_:mode:to:)` throws
  `unsupportedFeature` unconditionally — P1-16 (done/) explicitly left
  "DocEngineHost engine-side save modes" undone and no task tracked that
  gap. Without it, annotations written via PDFium's C API can never reach
  disk, so this task's "spec-compliant storage"/round-trip acceptance
  criteria can't be fully met. Filed `tasks/escalations/E-009-p1-04-engine-save-missing.md`
  and a new backlog task `tasks/backlog/phase-1-core-pillars/P1-21-docengine-save-modes.md`
  (Critical — blocks every Phase 1/2 mutation feature, not just this one).
  Also: no fixture corpus of real Acrobat/Preview-annotated PDFs exists
  (`tasks/escalations/E-005-corpus-acquisition-gap.md` already covers this
  class of gap) — the interop round-trip acceptance criterion needs one.
  Also: `DocumentSession` has no undo/redo mechanism yet at all (confirmed:
  no `Undo`/`Command` types in `Sources/DocumentSession/`) despite this
  task's AC assuming "DocumentSession's undo stack" exists — building a
  first, annotation-scoped version of that mechanism is in scope here.
- No existing drag-to-select gesture UI in the viewer (P1-03 built search
  highlighting over existing `TextRun`s, not interactive text selection).
  Scoping "selection-driven creation" down to click-to-select an existing
  `TextRun`'s bounding box (reusing P1-03's geometry) rather than building
  new multi-run drag-selection + quad-merging in this PR — noted as a scope
  cut in the PR body.

**Plan:**
1. `docs/adr/ADR-014-pdfengineapi-annotation-quadpoints.md` — additive
   frozen-seam change: `Annotation` gains `quadPoints: [PDFQuad]`,
   `opacity: Double`, `createdAt: Date?`. `[INTEGRATION]` PR per ADR-006/§3.6,
   self-mergeable once ADR present + CI green (ADR-008 precedent: ADR-013).
2. `PDFEngineAPI`: add `PDFQuad`, extend `Annotation`, keep old initializer
   call sites source-compatible via defaults. Extend `ConformanceSuite.verifyAnnotationStore`
   to check quad round-trip.
3. `DocEngineHost`: add `fpdf_annot.h` (+ its `fpdf_formfill.h` dependency)
   to `CPDFium`'s module map; implement `AnnotationStore` on `PDFiumEngine`
   using real PDFium annot calls (create/get/set/remove, attachment points
   for quads, color+alpha, `/T`+`/Contents`+`/M` string values). Test via
   `PDFEngineConformanceSuite.verifyAnnotationStore` run against the real
   engine, plus engine-specific tests for quad ordering/color/opacity/author
   round-trip through PDFium's own read-back (the achievable round-trip
   signal per E-009's interim decision).
4. `DocumentSession`: `AnnotationSession` (add/update/remove/list over the
   wired engine) + a small command-based `AnnotationUndoStack` (first undo
   primitive in this package — scoped to annotation ops, documented as
   such) + `MarkupToolbarView`/view model (subtype+color buttons, acting on
   a caller-supplied `TextRun`/`PDFRect`; click-to-select existing markup +
   delete). Unit tests via `FakePDFEngine`.
5. Update `Packages/DocEngineHost/CLAUDE.md` + `Packages/DocumentSession/CLAUDE.md`
   + relevant `okf/` files. PR body states plainly: file-persisted
   round-trip and Acrobat/Preview fixture comparison are NOT met (blocked
   on P1-21 + fixture acquisition), everything else is.

**Risks:** PDFium quad-point ordering is a known spec/implementation
mismatch area — must document the exact order used and why. `FS_QUADPOINTSF`/`FS_RECTF`
struct layout needs care crossing the C shim.
