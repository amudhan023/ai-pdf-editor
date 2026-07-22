# P2-08 — Ingestion Pipeline: Stage Graph, Normalizer & Classifier

**Owner:** claude-agent · **Branch:** task/P2-08-ingestion-stage-graph · **Claimed:** 60b4cb8abb2a614cfe56f31eea81b23df88646c1


**Epic:** E11 · **Primary package:** `Packages/IngestionPipeline` · **Complexity:** L · **Priority:** High

## Goal
The ingestion backbone (ARCHITECTURE.md §5.1): accept PDF/DOCX/images → normalize → OCR-if-needed → classify document type → route to extractors → emit `ExtractionCandidate[]`; plus the document classifier model integration.

## Background
PRD FR-3.1/3.2. Pipeline emits candidates only — persistence happens in the review session (P2-11). Extractors plug in as stages (P2-09/10 are parallel-friendly because of this seam).

## Requirements
- Stage-graph runtime: typed stage protocol, cancellable, progress reporting, per-stage error isolation (bad stage ≠ dead pipeline).
- Normalizer: DOCX/RTF/TXT text extraction, image preprocessing (deskew/contrast via P1-13 pipeline), HEIC handling, PDF page rasterization via engine.
- Classifier endpoint integration (bundled Core ML model via registry): passport | license | resume | filled-form | certificate | utility-bill | generic, with confidence.
- `ExtractionCandidate` type: value, proposed vault path, source region (doc/page/rect), confidence, extractor attribution.

## Dependencies
- P1-12, P1-13.

## Files Likely Affected
- `Packages/IngestionPipeline/Sources/{Graph,Normalize,Classify}/**`.

## Acceptance Criteria
- Classifier ≥90% top-1 on synthetic fixture set (bench-gated); misclassification routes to generic extractor, never a crash.
- Pipeline handles a corrupt DOCX and a 50MB photo gracefully (typed errors, bounded memory).

## Definition of Done
- Global DoD.

## Testing Requirements
- Stage-graph unit tests (cancellation, error isolation); classifier bench; format-matrix ingestion smoke.

## Documentation Updates
- `IngestionPipeline/CLAUDE.md` stage-authoring guide (extractor tasks depend on it).
