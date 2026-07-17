# P1-03 — Engine Text Extraction & Full-Text Search

**Epic:** E2/E3 · **Primary package:** `Packages/DocEngineHost` (+ search UI in DocumentSession) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

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
