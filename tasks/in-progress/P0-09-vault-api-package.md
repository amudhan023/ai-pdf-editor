**Owner:** claude-code (session P0-09) · **Branch:** task/P0-09-vault-api-package · **Claimed:** 094af94

# P0-09 — VaultAPI Package: Schema Types & PolicyTicket (Freeze Point)

**Epic:** E8 · **Primary package:** `Packages/VaultAPI` · **Complexity:** M · **Priority:** Critical

## Goal
Define the vault domain model (persons, sections, field paths, sensitivity tiers, provenance, history lists, relationships) and the `PolicyTicket` capability type — the contract for Vault.xpc, autofill, and ingestion.

## Background
ARCHITECTURE.md §3.2 (VaultModel), §8.2 (schema), §3.3 (PolicyTicket handshake). PRD FR-2.1–2.5. M0 freeze point: Track B and Track C both build against these types.

## Requirements
- Typed field-path system (`identity.passport.number`), field value types (string/date/number/enum/list), sensitivity tiers, alias lists, verified-at metadata.
- Person/organization profiles + typed relationship edges; history-list entry types with date ranges.
- Provenance model (manual | document+page+region+confidence).
- `PolicyTicket`: operation-scoped, time-boxed, field-path-scoped grant token (opaque signature payload; signing lives in PolicyKit).
- Client protocol for vault operations (CRUD, compare-read, crypto-shred) — implementation-free; `FakeVaultClient` included.

## Dependencies
- P0-01.

## Files Likely Affected
- `Packages/VaultAPI/Sources/**`, `Tests/**`.

## Acceptance Criteria
- Canonical field-path catalog covers PRD FR-2.1 sections incl. custom-field extension mechanism.
- `FakeVaultClient` passes shared conformance suite (reused against real Vault.xpc later).

## Definition of Done
- Global DoD, plus: freeze recorded in ADR-007-vaultapi-v1.md.

## Testing Requirements
- Path parsing/validation tests; Codable round-trips; conformance suite.

## Documentation Updates
- Package `CLAUDE.md`; field-path catalog doc in docs/specs/vault-schema.md.
