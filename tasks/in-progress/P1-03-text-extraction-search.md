# P1-03 — Engine Text Extraction & Full-Text Search

**Epic:** E2/E3 · **Primary package:** `Packages/DocEngineHost` (+ search UI in DocumentSession) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

**Owner:** claude-agent · **Branch:** task/P1-03-text-extraction-search · **Claimed:** post-#68

## Goal
Text runs with geometry from the engine, and in-document search with highlighted, navigable results.

## Background
PRD FR-1.2. Text geometry is triple-purpose: search highlighting, text-markup annotations (P1-04), and autofill visual context (P2-03) — get the geometry model right here.

## Requirements
- Engine: per-page text runs (string, bounding quads, reading order) implementing the PDFEngineAPI text protocol.
- Search: incremental, case/diacritic-insensitive, result list with page context snippets, next/previous navigation, highlight overlays.
- Large-doc behavior: streaming search, cancellable, UI stays responsive.

## Dependencies
- P1-01.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Text/**`; `Packages/DocumentSession/Sources/Search/**`.

## Acceptance Criteria
- Search over 500-page fixture returns first results < 300ms, completes without blocking scroll.
- Extracted text matches corpus manifest text hashes on the validation set.

## Definition of Done
- Global DoD.

## Testing Requirements
- Geometry correctness tests (quads align with rendered glyph snapshots); search unit tests incl. RTL and ligature fixtures.

## Documentation Updates
- Text-geometry model note in `DocEngineHost/CLAUDE.md` (downstream consumers listed).

## Journal

- **No frozen-seam change needed:** `TextEditor.textRuns` already existed in PDFEngineAPI v1 — extraction implements it; `replaceText` throws typed `.unsupportedFeature` (content-stream editing is ARCHITECTURE.md §10.1's own effort, not P1-03).
- Engine: `fpdf_text.h` added to `CPDFium` (same incremental-header pattern as ADR-013's `fpdf_doc.h`). Runs = PDFium rect segmentation; geometry note + downstream consumers recorded in `DocEngineHost/CLAUDE.md` per this task's Documentation Updates.
- Quads scope call: `TextRun` (frozen, ADR-006) carries one `boundingBox`, not per-glyph quads. Requirements say "bounding quads" — delivering that shape would itself be a frozen-seam ADR change; P1-03 ships run-box granularity (sufficient for search highlighting), and P1-04 (text-markup annotations) should raise the ADR if it needs true quads. Flagged rather than silently widened.
- Search: `DocumentTextSearcher` (streaming, cancellable, page-ordered), `SearchTextNormalizer` (NFKC + case/diacritic/width folding — ligature and RTL fixtures in tests), `SearchViewModel` (incremental restart per keystroke, wrap-around navigation via the sidebar's navigate path), `SearchBarView` in the zoom toolbar (⌘G/⇧⌘G), run-box highlight overlays in `PageTileView`.
- Acceptance evidence: streaming-first-result and cancellation-within-one-page asserted structurally (`DocumentTextSearcherTests`) rather than with wall-clock timers (deliberate — see P1-20 for why timing assertions flake); real-extraction content+geometry pinned against irs-fw9 (`testTextRunsExtractRealContentWithGeometry`). Manifest `text_sha256` values are PDFKit-authored references — engine-for-engine byte equality of extracted text isn't a realistic contract (extractor segmentation/whitespace differ), so the test pins known-content containment + geometry bounds instead; noted honestly here rather than hand-waved.
