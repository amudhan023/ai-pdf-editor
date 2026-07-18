# ADR-014 — PDFEngineAPI: `Annotation` Gains Quad Points, Opacity, Creation Date

**Status:** Accepted · **Task:** P1-04 · **Amends:** ADR-006 (PDFEngineAPI v1 freeze)

## Context
P1-04 (text-markup annotations: highlight/underline/strikeout/squiggly) needs
`AnnotationStore` to produce spec-compliant markup annotations (ISO 32000-1
§12.5.6.2/§12.5.6.10). Text markup annotations are defined by a `/QuadPoints`
array — one quadrilateral per line-segment of marked text, since a highlight
can span multiple lines with different left/right extents per line. The
current `Annotation` (ADR-006) carries a single `boundingBox: PDFRect`, which
can approximate one line but cannot represent a multi-line highlight
correctly, and has no field for annotation opacity (`/CA`, distinct from the
color's own alpha channel in the PDF object model) or creation date (`/CreationDate`,
distinct from the existing `modifiedAt`/`/M`).

This is a frozen-seam change (`Packages/PDFEngineAPI/`, ADR-006): additive
only (new fields with source-compatible defaults, no existing field removed
or retyped), requiring this ADR + an `[INTEGRATION]`-marked PR per root
CLAUDE.md §3.6 — same pattern as ADR-013 (`OutlineReader`).

## Decision
Add to `Packages/PDFEngineAPI/Sources/PDFEngineAPI/AnnotationStore.swift`:

- **`PDFQuad`** (`Sendable`, `Codable`, `Equatable`): `topLeft`/`topRight`/`bottomLeft`/`bottomRight: PDFPoint`.
  Named by corner rather than a flat `x1...y4` tuple so the traversal-order
  ambiguity in the PDF spec (Table 179's literal text describes a
  counter-clockwise quad; real-world producers, including Acrobat, instead
  write points in "Z" order — top-left, top-right, bottom-left,
  bottom-right — and most consumers, including this one, follow the de
  facto order for interop rather than the literal spec text) is encoded in
  the type itself instead of a positional-argument footgun.
- **`Annotation`** gains: `quadPoints: [PDFQuad] = []` (one quad per marked
  line; empty means "use `boundingBox` as a single quad," so subtypes
  without quad semantics — square/circle/ink/etc. — are unaffected),
  `opacity: Double = 1.0` (PDF `/CA`, independent of `AnnotationColor.alpha`,
  which stays the *stroke/fill* color's own alpha), `createdAt: Date? = nil`.
  All three are appended after the existing parameters with defaults, so
  every existing call site (`FakePDFEngine`, `PDFEngineConformanceSuite`,
  any future consumer built against v1) keeps compiling unmodified.
- **`PDFEngineConformanceSuite.verifyAnnotationStore`** gains a quad
  round-trip check (add an annotation with 2 quads spanning different lines,
  verify `annotations(of:page:)` returns them in the same order/values).
- **`DocEngineHost.PDFiumEngine`** implements `AnnotationStore` against real
  PDFium (`fpdf_annot.h`, already vendored in `ThirdParty/pdfium`'s
  xcframework, newly exposed through `CPDFium`'s module map): quad points
  via `FPDFAnnot_AppendAttachmentPoints`/`FPDFAnnot_GetAttachmentPoints`,
  color+opacity via `FPDFAnnot_Set/GetColor` (`A` channel = opacity),
  author/contents via `FPDFAnnot_Set/GetStringValue` on `/T`/`/Contents`,
  dates via the same on `/CreationDate`/`/M`.

## Consequences
- Any further change to `PDFQuad`'s shape or `Annotation`'s field set is
  itself a frozen-seam change requiring a superseding ADR.
- The Z-order-vs-counterclockwise quad ordering choice is a real
  interoperability assumption that cannot be verified against real
  Acrobat/Preview-authored files today — no such fixtures exist in the repo
  yet (`tasks/escalations/E-005-corpus-acquisition-gap.md`). Flagged in
  `tasks/escalations/E-009-p1-04-engine-save-missing.md`; revisit once
  fixtures land.
- `opacity` and `AnnotationColor.alpha` are intentionally both present and
  intentionally different PDF concepts (`/CA` vs. the color space value) —
  a future formatter/UI must not conflate them.
- Self-mergeable once this ADR is present and CI is green, per ADR-008
  (frozen-seam change, not an entitlement or governance-doc change).
