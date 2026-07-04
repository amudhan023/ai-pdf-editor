# P2-10 — Extractors: Resume NER & Filled-Form Reader

**Epic:** E11 · **Primary package:** `Packages/IngestionPipeline` (extractors) · **Complexity:** L · **Priority:** High

## Goal
Two more profile sources: NER-based extraction from resumes/generic documents (names, contacts, employment/education history with date ranges), and the lossless filled-AcroForm reader (existing field values → candidates via reverse matching).

## Background
PRD FR-3.3/FR-3.6. Filled forms are gold: typed values with explicit labels — reuse the matching ladder (P1-14/P2-03) in reverse (field label → vault path) at high confidence. Resume NER feeds the history lists that make immigration forms fillable.

## Requirements
- NER stage: entity extraction endpoint (bundled model via registry) + resume-structure heuristics (section headers, date-range parsing → employment/education history candidates with ranges).
- Filled-form reader: FormModel values → (label, value) pairs → matcher → candidates; checkbox/radio export values decoded to enums.
- Generic-document fallback: NER over any OCR'd text, conservative confidence.
- All candidates carry region provenance.

## Dependencies
- P2-08; matcher reuse from P2-03 (API only).

## Files Likely Affected
- `Packages/IngestionPipeline/Sources/Extractors/{NER,FilledForm}/**`.

## Acceptance Criteria
- Resume fixture set: ≥85% acceptance-rate proxy on extraction bench (PRD metric groundwork); date ranges parsed correctly across common formats.
- Filled W-9 fixture ingests every field losslessly with correct vault paths.

## Definition of Done
- Global DoD.

## Testing Requirements
- NER bench vs annotated fixtures; date-range parser property tests; filled-form round-trip (fill via P2-05 → ingest → identical values).

## Documentation Updates
- docs/specs/ingestion-extractors.md coverage table.
