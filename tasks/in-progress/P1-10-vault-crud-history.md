# P1-10 — Vault CRUD, Provenance & History Lists

**Owner:** claude-agent · **Branch:** task/P1-10-vault-crud-history · **Claimed:** 53502e2645d2efa403bb1f6b0445b6671a4fd472

**Epic:** E8 · **Primary package:** `Packages/VaultStore` · **Complexity:** M · **Priority:** High

## Goal
Complete the vault data operations: field CRUD with provenance, multi-profile + relationship management, history-list entries with date ranges, compare-read for conflict detection, and audited field-scoped reads.

## Background
PRD FR-2.1–2.3, FR-2.5. ARCHITECTURE.md §8.2 — history lists are first-class tables (gap-detection queries later). Every read is field-scoped + logged (AuditLog integration point via domain events; log lands in P1-15).

## Requirements
- CRUD for fields/sections/custom fields with alias lists and verified-at; batch transactional writes (ingestion "accept set" = one tx).
- Person/org profiles, typed relationship edges; delete-person cascade rules.
- History entries (addresses/employers/travel) with date-range queries.
- Compare-read grant type (returns match/mismatch summaries, not values, for ingestion conflict UI).
- Sensitive-tier reads enforce PolicyKit freshness (from P1-09).

## Dependencies
- P1-08, P1-09.

## Files Likely Affected
- `Packages/VaultStore/Sources/Operations/**`.

## Acceptance Criteria
- Conformance suite extended for history/relationships/compare-read passes.
- Access events emitted for every read/write with field paths + ticket IDs (values never in events).

## Definition of Done
- Global DoD.

## Testing Requirements
- Transactionality tests (partial batch failure rolls back); date-range query tests; cascade tests.

## Documentation Updates
- docs/specs/vault-schema.md updated with any catalog additions.
