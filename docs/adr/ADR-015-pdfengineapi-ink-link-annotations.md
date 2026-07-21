# ADR-015 — PDFEngineAPI: `Annotation` Gains Ink Paths and Link Target; `AnnotationSubtype` Gains `.link`

**Status:** Accepted · **Task:** P1-05 · **Amends:** ADR-006 (PDFEngineAPI v1 freeze), ADR-014 (quad points/opacity/createdAt)

## Context
P1-05 extends the annotation set (P1-04 covered text markup only) to geometry-drawn
subtypes: notes, free text, ink, shapes, stamps, and link. `AnnotationSubtype`
(ADR-014) already anticipated most of these (`.text`, `.ink`, `.square`, `.circle`,
`.line`, `.freeText`, `.stamp`, `.popup`) but has no `.link` case, and `Annotation`
has no field capable of representing an ink annotation's stroke geometry — a
freehand ink mark is a **list of polylines** (PDF `/InkList`: one array of points
per continuous stroke, ISO 32000-1 §12.5.6.13), which `quadPoints`/`boundingBox`
cannot express (a quad is a single 4-corner rectangle per line of *text*, not an
arbitrary point path).

This is a frozen-seam change (`Packages/PDFEngineAPI/`, ADR-006): additive only,
same pattern as ADR-013/ADR-014.

## Decision
Add to `Packages/PDFEngineAPI/Sources/PDFEngineAPI/AnnotationStore.swift`:

- **`AnnotationSubtype.link`** — the one PDF markup-adjacent subtype ADR-014
  didn't add (it also carries `/QuadPoints`, like text markup, per PDFium's own
  `FPDFAnnot_HasAttachmentPoints` doc comment).
- **`Annotation.inkPaths: [[PDFPoint]] = []`** — one array per ink stroke; empty
  for every subtype except `.ink` (mirrors `quadPoints`' "empty means not
  applicable" convention from ADR-014). Existing call sites keep compiling
  unmodified (appended parameter with a default).
- **`Annotation.linkURL: URL? = nil`** — the URI target of a `.link` annotation's
  action, when one exists. **Read-only in practice**: PDFium's public C API
  (`fpdf_annot.h`/`fpdf_doc.h`, both fully vendored in `ThirdParty/pdfium`) has
  no setter for an annotation's action dictionary (`/A`) — `FPDFLink_GetAction`/
  `FPDFAction_GetURIPath` exist, `FPDFAnnot_SetAction` does not. `DocEngineHost.add`
  therefore throws a typed `.unsupportedFeature("linkActionNotCreatable")` when
  `linkURL != nil` is supplied to `add(_:to:)` for a `.link` annotation, rather
  than silently dropping it — see CLAUDE.md §15 ("never swallow"). Creating a
  bare `.link` region (rect/quad, no action) is supported; wiring a real URI
  action is not achievable without a PDFium API this product doesn't have
  access to change (frozen third-party pin, CLAUDE.md §17).
- **`PDFEngineConformanceSuite.verifyInkAnnotation`** (new function, existing
  `verifyAnnotationStore` left untouched) — add an ink annotation with 2 stroke
  paths, verify `annotations(of:page:)` returns them in the same order/values.
- **`DocEngineHost.PDFiumEngine`** implements ink read/write via
  `FPDFAnnot_AddInkStroke`/`FPDFAnnot_GetInkListCount`/`FPDFAnnot_GetInkListPath`
  (already-vendored `fpdf_annot.h`, no new header exposure needed — P1-04
  already copied the file in full, confirmed byte-identical to
  `ThirdParty/pdfium`'s upstream copy) and link-URI read via `fpdf_doc.h`'s
  `FPDFLink_Enumerate`/`FPDFLink_GetAnnot`/`FPDFLink_GetAction`/
  `FPDFAction_GetType`/`FPDFAction_GetURIPath` (also already vendored, unused
  until now).

## Consequences
- `.line` remains a valid `AnnotationSubtype` value (spec-complete enum, ADR-014's
  intent) but is **not creatable** by this engine: PDFium's
  `FPDFAnnot_IsSupportedSubtype` creation list (`fpdf_annot.h`'s own doc comment)
  omits `line` — confirmed by `PDFiumAnnotationStoreTests.testUnsupportedCreationSubtypeFailsTyped`
  (already existing, from P1-04) and re-verified here. P1-05's "lines/arrows"
  requirement is **not met** by this task; see
  `tasks/escalations/E-010-p1-05-line-annotations-unsupported.md`. No superseding
  PDFium API exists in the pinned vendor drop to build one from (no `/L` setter,
  no generic dictionary-array setter, and `FPDFAnnot_AppendObject`'s own doc
  comment restricts custom-object annotations to ink/stamp only) — this is a
  genuine engine-capability gap, not a scope choice.
- Any further change to `Annotation`'s field set or `AnnotationSubtype`'s cases
  is itself a frozen-seam change requiring a superseding ADR.
- `linkURL` populated by `DocEngineHost` is best-effort read support for
  *pre-existing* (e.g. Acrobat-authored) link actions once real fixtures exist
  (`E-005-corpus-acquisition-gap.md`); this product cannot itself author a
  clickable link with a URI target today.
- Self-mergeable once this ADR is present and CI is green, per ADR-008
  (frozen-seam change, not an entitlement or governance-doc change).
