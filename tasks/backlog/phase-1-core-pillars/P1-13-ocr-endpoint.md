# P1-13 — OCR Endpoint & Searchable Text Layer

**Epic:** E10/E2 · **Primary package:** `Packages/InferenceHost` (Vision adapter) + text-layer write in `DocEngineHost` `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Real OCR through the Vision adapter (text + geometry + confidence, language auto-detect) and "Make Searchable" — writing an invisible text layer into scanned PDFs.

## Background
PRD FR-1.7 (NFR-A3 accuracy bars); ingestion (P2-08) and flat-form autofill (P3-01) consume the same endpoint. Text-layer write goes through the engine's save path.

## Requirements
- OCR endpoint: page image → text runs with quads, per-run confidence, detected language; batch (background queue) and single-page (interactive) modes.
- Photo-input tolerance: deskew/contrast preprocessing pipeline stage.
- "Make Searchable" document action: OCR all raster pages → invisible text layer → atomic save; progress UI hook via DocumentSession.

## Dependencies
- P1-12; text-layer write also needs P1-16.

## Files Likely Affected
- `Packages/InferenceHost/Sources/Vision/**`; `Packages/DocEngineHost/Sources/TextLayer/**`.

## Acceptance Criteria
- NFR-A3: ≥98% char accuracy on 300-dpi fixture set, ≥93% on phone-photo set (bench suite, CI-gated).
- OCR'd PDF is searchable in-app and in Preview/Acrobat (text layer interop).

## Definition of Done
- Global DoD, plus: OCR accuracy added to bench trend dashboard.

## Testing Requirements
- Accuracy bench vs fixture manifests; geometry alignment tests; 12-language smoke set.

## Documentation Updates
- Fixtures README (OCR ground-truth format).
