# P2-16 — Export Suite: Flatten, Images, Text, Compression

**Epic:** E5 · **Primary package:** `Packages/DocEngineHost` (export) + export UI in `DocumentSession` `[INTEGRATION]` · **Complexity:** M · **Priority:** Medium

## Goal
MVP export set (PRD FR-1.11 subset + FR-1.12): flattened PDF (annotations/forms burned in), PNG/JPEG per page, plain text, file-size optimization presets, and apply/remove password protection.

## Background
Flatten matters doubly here: filled government forms are usually submitted flattened (PRD "verify before submitting" UX hooks in). Word/PDF-A export is deliberately H1 — don't scope-creep it in.

## Requirements
- Flatten: annotations + form fields → content stream, metadata preserved; per-export choice (flatten forms only / all).
- Raster export: page range, DPI/format options; text export in reading order (P1-03 order).
- Optimization presets: image downsampling/recompression, unused-object sweep, font-subset dedupe; before/after size preview.
- Encryption: apply/remove AES-256 with user password + permission flags (remove requires current password).
- Export sheet UI with per-format options; batch page-range support.

## Dependencies
- P1-16; flatten of fills coordinates with P2-01 appearance streams.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Export/**`; `Packages/DocumentSession/Sources/Export/**`.

## Acceptance Criteria
- Flattened filled W-9 renders identically (snapshot) with zero interactive fields remaining.
- Optimization preset shrinks scan-heavy fixture ≥40% with no visible quality loss at preset "balanced".

## Definition of Done
- Global DoD.

## Testing Requirements
- Flatten equivalence snapshots; encryption round-trip (we + Acrobat can open); optimizer corpus suite (valid output, size deltas recorded).

## Documentation Updates
- None beyond package CLAUDE.md.
