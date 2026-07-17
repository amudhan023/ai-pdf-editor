# ADR-013 — PDFEngineAPI: Add `OutlineReader` Protocol

**Status:** Accepted · **Task:** P1-02 · **Amends:** ADR-006 (PDFEngineAPI v1 freeze)

## Context
P1-02 (thumbnail sidebar + outline/TOC navigation) needs to read a document's
outline (PDF spec `/Outlines` bookmark tree: nested titled entries, each
targeting a page and optional zoom) so `DocumentSession`'s sidebar can render
and navigate it. No protocol in `PDFEngineAPI` v1 (ADR-006) exposes this —
`PageRenderer`/`PageOrganizer`/etc. are all page-content or page-order
concerns, not document-level metadata like the outline tree. `DocEngineHost`'s
`CPDFium` shim also doesn't declare the PDFium bookmark functions yet
(`fpdfview.h` only carries the opaque `FPDF_BOOKMARK` typedef, no
`FPDFBookmark_*` function declarations) — per that package's own CLAUDE.md,
headers are added incrementally as real usage needs them, which this task now
does.

This is a frozen-seam change (`Packages/PDFEngineAPI/`, ADR-006): additive only
(a new protocol + new value types; no existing protocol signature changes),
but still requires this ADR + an `[INTEGRATION]`-marked PR per root
CLAUDE.md §3.6.

## Decision
Add to `Packages/PDFEngineAPI/Sources/PDFEngineAPI/`:

- **`OutlineNode`** (`Sendable`, `Codable`, `Equatable`, `Identifiable`): `title:
  String`, `destinationPage: PageIndex?` (`nil` for a structural heading with
  no page target), `zoom: Double?` (optional target zoom level from the PDF
  destination), `children: [OutlineNode]`.
- **`OutlineReader`** protocol: `func outline(of document: DocumentHandle)
  async throws -> [OutlineNode]` — the top-level roots of the tree; an empty
  array means the document has no outline (not an error).
- **`FakePDFEngine`** gains `OutlineReader` conformance plus a `seedOutline(_
  nodes:for:)` test-seeding convenience (same pattern as `seedFields`/
  `seedTextRuns`), and `PDFEngineConformanceSuite.verifyOutlineReader` so
  `DocEngineHost`'s real implementation is checked against the same contract.
- **`DocEngineHost.PDFiumEngine`** implements `OutlineReader` using PDFium's
  `FPDFBookmark_GetFirstChild`/`GetNextSibling`/`GetTitle`/`GetDest` +
  `FPDFDest_GetDestPageIndex` (declarations added to `CPDFium`'s header
  surface, mirroring the existing `fpdf_edit.h`-for-rotation-only pattern —
  only the bookmark/dest functions actually called are declared, not the
  whole PDFium doc-metadata header).
- **`App/`'s composition root** passes the same `PDFiumEngine` instance as an
  `outlineReader:` argument alongside its existing `lifecycle:`/`renderer:`
  wiring (one instance, three protocol roles — no new engine object).
  `DocumentSession`'s `outlineReader` parameter defaults to `nil` so existing
  call sites (including `FakePDFEngine`-backed tests that don't care about
  outlines) are unaffected; `outline()` returns `[]` when no reader is wired.

## Consequences
- Any further change to `OutlineNode`'s shape or `OutlineReader`'s signature
  is itself a frozen-seam change requiring a superseding ADR.
- A document with a corrupt or cyclic bookmark tree is a real-world PDFium
  hazard; `PDFiumEngine.outline(of:)` bounds traversal depth (matching the
  existing "never crash on malformed input" rule, CLAUDE.md §15) rather than
  trusting the tree to be acyclic.
- Self-mergeable once this ADR is present and CI is green, per ADR-008
  (frozen-seam change, not an entitlement or governance-doc change).
