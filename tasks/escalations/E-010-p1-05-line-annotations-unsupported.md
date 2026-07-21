# E-010 — P1-05: line/arrow annotations and link-action creation unsupported by pinned PDFium

**Status:** Open (documented scope cut, not blocking)
**Raised by:** P1-05 (Annotations: Notes, Free Text, Ink, Shapes, Stamps)
**Related:** ADR-015, `tasks/done/P1-04-annotations-markup.md`, E-009 (resolved by P1-21)

## Summary

P1-05's task file lists "lines/arrows" and "link annotations (view + create)" among
the required subtypes. Two parts of that list are not achievable with the currently
pinned PDFium build's public C API, confirmed by reading the vendored headers
directly (not inferred):

1. **`.line` cannot be created.** `FPDFAnnot_IsSupportedSubtype`'s own creation
   allow-list (checked in `fpdf_annot.h`) omits `FPDF_ANNOT_LINE` — `FPDFPage_CreateAnnot`
   fails for it. This was already discovered and tested in P1-04
   (`testUnsupportedCreationSubtypeFailsTyped`); P1-05 re-confirmed it still holds
   and added no redundant new investigation. Arrows would be a `.line` with
   `/LE` endpoint styling, so they inherit the same gap.
2. **A `.link` annotation's URI action (`/A` dict) cannot be authored.** `fpdf_doc.h`
   exposes `FPDFLink_GetAction`/`FPDFAction_GetURIPath` (read-only) but there is no
   `FPDFAnnot_SetAction`-equivalent setter anywhere in the pinned header set. A bare
   link *region* (rect/quad, no action) can be created and round-trips; a link with
   a working "click to open URL" action cannot.

## What P1-05 did instead

- `.line` remains uncreatable, same as P1-04; not re-litigated further this pass.
- `.link` creation succeeds for a bare region (`linkURL == nil`) and throws a typed
  `PDFEngineError.unsupportedFeature("linkActionNotCreatable")` if a caller supplies
  a non-nil `linkURL` at creation time — an honest failure, not a silent no-op
  (CLAUDE.md §2 "Honest failure").
- Reading existing links (e.g. from an Acrobat-authored fixture) works: `annotations(of:page:)`
  best-effort resolves each link's URI action via `FPDFLink_Enumerate` +
  `FPDFAction_GetURIPath` and populates `Annotation.linkURL`.
- The toolbar UI (`MarkupToolbarViewModel`) does not offer `.ink` or `.link` in its
  picker for a different, UI-only reason (no freehand-stroke gesture, no meaningful
  URI source in the toolbar flow) — both remain fully engine/session-tested via
  `PDFEngineConformanceSuite`/`PDFiumAnnotationStoreTests`, just not toolbar-reachable
  this pass.

## Path to resolution

Only a PDFium version bump could add `FPDFAnnot_SetAction`-equivalent or `.line`
creation support, if upstream has since added one — that is its own PR per
CLAUDE.md §17 ("Upgrades are their own PRs, never bundled with features"), including
the full corpus + security suite re-run. Until then, this escalation stays open as
a known, load-bearing engine-capability boundary, not a bug to chase in this task.
