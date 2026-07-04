# P2-12 — FormKnowledge: Fingerprinting, Mapping Memory & Template Packs

**Epic:** E12 · **Primary package:** `Packages/FormKnowledge` · **Complexity:** M · **Priority:** High

## Goal
Recognize forms and remember mappings: structural fingerprinting, correction-derived mapping memory (paths + formats, never values), and signed bundled template packs for top target forms — consulted before ML in the matching ladder.

## Background
ARCHITECTURE.md §3.2/§4; PRD FR-4.8/4.9 (memory GA is H1, but capture starts now) and R2 mitigation (template packs = deterministic fallback for the worst forms).

## Requirements
- Fingerprint: field-structure hash (names/kinds/order) + fuzzy layout similarity for flat forms (geometry sketch); versioned algorithm.
- Mapping store (`forms.db`, plain GRDB): fingerprint → {field → vault path + transform}; written from `FillCommitted` correction events; read API for the matcher's rung-0.
- Template pack format: signed JSON bundle (fingerprint + mappings + format rules); loader verifies signature; ship packs for ≥10 fixture forms (W-9, I-9, DS-160-class…).
- Privacy guard: schema has no value column; lint/test enforces.

## Dependencies
- P2-01 (FormModel), P2-05 (correction events); matcher integration point with P2-03 (API coordination).

## Files Likely Affected
- `Packages/FormKnowledge/Sources/**`; pack fixtures in `Fixtures/forms/packs/`.

## Acceptance Criteria
- Refill of a previously corrected fixture form: corrected mapping wins at rung-0 with high confidence (bench-verified improvement).
- Tampered pack refused; pack-covered form matches at 100% on manifest.

## Definition of Done
- Global DoD.

## Testing Requirements
- Fingerprint stability tests (reordered/revised form versions); memory learn/recall tests; signature verification tests.

## Documentation Updates
- docs/specs/template-pack-format.md (external authors will use this in H3).
