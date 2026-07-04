# P2-04 — ValueFormatter: Format Adaptation Engine

**Epic:** E12 · **Primary package:** `Packages/AutofillEngine` · **Complexity:** M · **Priority:** Critical

## Goal
Deterministic value rendering into target-field formats: dates (all layouts incl. split boxes), phones, SSN/EIN patterns, comb distribution, enum→checkbox/radio export values, composite splits (name/address), state abbreviations.

## Background
PRD FR-4.3; ARCHITECTURE.md §7.2 prompt hygiene: deterministic rules first; LLM fallback (if ever) is validated against source — digits may never change. Pure functions, no I/O — highly parallel-safe with P2-03 (different source dirs).

## Requirements
- Format-hint interpretation from FormModel (format strings, maxlen/comb, adjacent-field grouping for split dates/SSN).
- Typed transforms: `VaultValue → FieldRendering` with reversible provenance (what transform was applied — feeds explainability FR-4.10).
- Enum mapping tables (gender, marital status, yes/no variants) with locale awareness; unmappable enum → low-confidence flag, never a guess.
- Hard validator: output must be lossless w.r.t. source value (digit/char preservation checks).

## Dependencies
- P2-01 (FormModel types), P0-09 (value types).

## Files Likely Affected
- `Packages/AutofillEngine/Sources/Formatting/**`.

## Acceptance Criteria
- Format fixture matrix (≥100 cases from real forms) passes; validator provably rejects a mutated-digit case.
- Split-field groups (DOB in 3 boxes) fill correctly on fixture forms.

## Definition of Done
- Global DoD.

## Testing Requirements
- Property tests (round-trip losslessness); exhaustive enum-table tests; locale matrix for dates/phones.

## Documentation Updates
- Transform catalog doc in docs/specs/value-transforms.md.
