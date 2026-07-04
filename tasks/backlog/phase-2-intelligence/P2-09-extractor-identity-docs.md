# P2-09 — Extractors: Passport MRZ & Driver's License PDF417

**Epic:** E11 · **Primary package:** `Packages/IngestionPipeline` (extractors) · **Complexity:** M · **Priority:** High

## Goal
High-precision deterministic extractors for identity documents: passport MRZ parsing (check-digit validated) and US/CA driver's license PDF417 barcode decoding (AAMVA), mapped to canonical vault paths.

## Background
PRD FR-3.3. These are the highest-confidence profile sources (deterministic, checksummed) — they anchor Priya's onboarding moment. Vision barcode detection + pure-Swift MRZ/AAMVA parsers (no ML judgment involved).

## Requirements
- MRZ: TD1/TD2/TD3 formats, check-digit validation per ICAO 9303, OCR-error correction candidates (O/0, I/1) only when check digits confirm; extracted: passport number, names, DOB, nationality, sex, expiry.
- PDF417/AAMVA: mandatory + common optional elements → vault paths (license number, class, address, DOB, expiry); jurisdiction quirks table.
- Visual-zone cross-check where available (MRZ vs printed fields → confidence boost or conflict candidate).
- Region provenance for every candidate (snippet display in review UI).

## Dependencies
- P2-08.

## Files Likely Affected
- `Packages/IngestionPipeline/Sources/Extractors/{MRZ,AAMVA}/**`.

## Acceptance Criteria
- MRZ: ≥99% field accuracy on synthetic passport fixture set incl. degraded scans (M4 gate metric).
- Invalid check digits → candidate flagged low-confidence, never silently corrected.

## Definition of Done
- Global DoD.

## Testing Requirements
- ICAO check-digit vectors; AAMVA versions matrix; degraded-image robustness set from fixtures.

## Documentation Updates
- Extractor coverage table in docs/specs/ingestion-extractors.md.
