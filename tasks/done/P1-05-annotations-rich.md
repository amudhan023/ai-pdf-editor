# P1-05 — Annotations: Notes, Free Text, Ink, Shapes, Stamps

**Owner:** claude-agent · **Branch:** task/P1-05-annotations-rich · **Claimed:** e303cbf86327eae3bed9c3616b3b7217fcc4bc64

**Epic:** E4 · **Primary package:** `Packages/DocEngineHost` + `DocumentSession` `[INTEGRATION]` · **Complexity:** L · **Priority:** High

## Goal
Complete the PRD FR-1.3 annotation set: sticky notes (with popup), free text boxes, freehand ink, lines/arrows/rectangles/ellipses, stamps, and link annotations (view + create).

## Background
Builds on P1-04's annotation store plumbing; these types are geometry-drawn rather than text-anchored. Coordinate with P1-04 owner on shared annotation-store files — serialize these two tasks or split store vs tools cleanly.

## Requirements
- Engine CRUD for each subtype with spec-compliant appearance streams (so other viewers render them).
- Tool palette UX: tool selection, drawing interactions, property inspector (color, width, opacity, font for free text); move/resize/delete.
- Note popups and comment list sidebar (author, date, reply-free v1).

## Dependencies
- P1-04.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Annotations/**`; `Packages/DocumentSession/Sources/Annotate/**`.

## Acceptance Criteria
- Every subtype round-trips with Acrobat/Preview (renders, selectable, editable).
- Ink drawing latency imperceptible (<8ms point-to-screen) on trackpad.

## Definition of Done
- Global DoD, plus: M1 annotation demo checklist in docs/specs/m1-demo.md.

## Testing Requirements
- Per-subtype serialization + snapshot tests; appearance-stream validation against corpus interop fixtures.

## Documentation Updates
- None beyond package CLAUDE.md files.

## Journal

**Engine capability discovery (read the real vendored PDFium headers, not guessed):**
- `.line` cannot be created — `FPDFAnnot_IsSupportedSubtype`'s own creation
  allowlist excludes `FPDF_ANNOT_LINE`. Same gap P1-04 already hit and tested;
  re-confirmed, not re-litigated.
- No PDFium API sets an annotation's `/A` action dict — `FPDFLink_GetAction`/
  `FPDFAction_GetURIPath` exist (read), no setter exists. A `.link` with a
  caller-supplied URL cannot be authored; a bare link region can.
- `FPDFAnnot_AppendObject` (used for stamps) is restricted by its own doc
  comment to `ink`/`stamp` subtypes.
- PDFium's internal `CPVT_GenerateAP` auto-generates appearance streams for
  square/circle/ink/text/popup (among others) but **not** freeText or stamp —
  so square/circle needed zero new engine code (existing rect+color path
  suffices, pinned by a regression test); freeText needed an explicit `/DA`
  string; stamp needed an explicitly appended appearance object.
- Both gaps documented in `docs/adr/ADR-015-pdfengineapi-ink-link-annotations.md`
  and `tasks/escalations/E-010-p1-05-line-annotations-unsupported.md`.

**PDFEngineAPI (frozen seam, ADR-015):** added `AnnotationSubtype.link`,
`Annotation.inkPaths: [[PDFPoint]]`, `Annotation.linkURL: URL?` — both new
fields trailing-default-valued on `init`, fully source-compatible, no
existing call site changed. Added `PDFEngineConformanceSuite.verifyInkAnnotation`.
17/17 PDFEngineAPI tests pass; `Scripts/verify.sh PDFEngineAPI` and
`Scripts/verify-integration.sh PDFEngineAPI` both green.

**DocEngineHost:** `PDFiumAnnotationStore.swift` gained ink stroke write/read
(`FPDFAnnot_AddInkStroke`/`GetInkListPath`), a default `/DA` string for
freeText, an appended rect appearance object for stamps
(`appendStampAppearance`), and best-effort link-URI reading
(`linkURLsByAnnotationName`, via `FPDFLink_Enumerate` + `FPDFAction_GetURIPath`
— UTF-8, unlike the UTF-16LE `FPDFAnnot_GetStringValue` family). Link creation
with a supplied `linkURL` throws typed `PDFEngineError.unsupportedFeature`.
31/31 DocEngineHost tests pass (incl. a new file-persisted round-trip test
for ink geometry, closing the ink half of E-009's disk round-trip gap).
`Scripts/verify.sh DocEngineHost` green.

**DocumentSession:** `MarkupToolbarViewModel`/`MarkupToolbarView` widened
from 4 to 9 pickable subtypes (note, freeText, square, circle, stamp added)
plus an opacity slider; `.ink`/`.link` deliberately not in the picker (no
freehand gesture, no meaningful toolbar URI source — both remain fully
engine/session-tested). Added `CommentSidebarViewModel`/`CommentSidebarView`
— a third `DocumentSidebarView` pane listing every `.text`-subtype
annotation document-wide (author/contents/date), select-to-navigate,
delete; reply-free v1. 92/92 DocumentSession tests pass.
`Scripts/verify.sh DocumentSession` green.

**Scope cuts (documented, not silently dropped):**
- No move/resize/reshape UI for any annotation subtype (same gap as P1-04).
- No freehand ink-drawing gesture in the viewer — ink is engine/session-complete
  but not toolbar-reachable; the `<8ms` ink-drawing-latency acceptance
  criterion is therefore unverified (no gesture exists yet to measure, and
  this headless dev environment can't bench live trackpad input anyway).
- `.line`/arrow creation and link-action authoring are impossible with the
  pinned PDFium build's public API (E-010) — not fixable without a PDFium
  version bump, which is its own PR per CLAUDE.md §17.
- Also fixed en route: `okf/architecture/module-map.md`'s `DocEngineHost`/
  `DocumentSession` rows had drifted stale since P1-04/P1-21 (still said
  "annotations/save pending" after both had landed) — corrected in the same
  PR since it was directly adjacent to this task's own okf updates.

**Commits on `task/P1-05-annotations-rich`:** ac0277f (PDFEngineAPI),
b41c230 (DocEngineHost engine CRUD), 58603a3 (toolbar widen), 5115687
(comment sidebar), a5b8fa2 (CLAUDE.md/okf docs).
