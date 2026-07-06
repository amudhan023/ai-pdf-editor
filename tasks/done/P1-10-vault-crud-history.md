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

## Journal

**Orient:** Read root CLAUDE.md, this task file, `Packages/VaultStore/CLAUDE.md` + its Tests/ listing, `Packages/VaultAPI/CLAUDE.md` (frozen seam, ADR-007), `VaultClient.swift`, `ConformanceSuite.swift`, `FakeVaultClient.swift`, `HistoryEntry.swift`/`Person.swift`/`ProfileField.swift`, `PolicyKit/PolicyRules.swift`/`TicketVerifier.swift`/`TicketClaims.swift`, and the existing `SQLCipherVaultStore.swift`/`Records.swift`/`VaultMigrations.swift`/`TicketVerifyingVaultClient.swift`.

**Finding:** P1-08/P1-09 already implemented full CRUD (persons, fields, history, relationships, compareRead, cryptoShred), FK `ON DELETE CASCADE` for all person-owned tables, and PolicyKit's sensitivity/auth-freshness gate at ticket-minting time (`PolicyRules.decide`) — so "delete-person cascade rules" and "sensitive-tier reads enforce PolicyKit freshness" were already structurally satisfied; this task only needed tests pinning that, plus the genuinely new capabilities below.

**Plan / what was added:**
1. `Operations/BatchFieldAcceptance.swift` — `acceptFields(_:ticket:)` on `SQLCipherVaultStore`: one GRDB transaction for a whole ingestion "accept set," all-or-nothing.
2. `Operations/HistoryDateRangeQuery.swift` — `historyEntries(category:overlapping:for:ticket:)`: SQL overlap query (`nil` end = ongoing) that gap-detection can build on later (ARCHITECTURE.md §8.2 explicitly defers the gap-detection algorithm itself).
3. `VaultAccessEvent.swift` + `SQLCipherVaultStore.accessEvents` (`AsyncStream`, `VaultLockEvent` precedent) — emits `{operation, personID, paths, ticketID, at}` after every successful ticket check on every read/write/compareRead/history/relationship call (acceptance criterion: "access events... field paths + ticket IDs... values never in events" — no value slot exists on the type, so that's structural, not a convention to remember).
4. `TicketVerifyingVaultClient` gained matching `where Inner == SQLCipherVaultStore` wrappers for both new Operations methods, so neither bypasses HMAC/replay verification (CLAUDE.md §3.3 "no bypass path").
5. `openedPool()`/`checkTicket(...)` on `SQLCipherVaultStore` and `inner`/`verify(...)` on `TicketVerifyingVaultClient` changed from `private` to internal (module-only) so the Operations/ extensions (different files, same target) can reach them — no external package exposure.

**Frozen-seam call:** `VaultAPI` (ADR-007) was deliberately *not* touched. The acceptance criterion "conformance suite extended for history/relationships/compare-read" is satisfied by new direct tests in `VaultStoreTests` (`BatchFieldAcceptanceTests`, `HistoryDateRangeQueryTests`, `PersonCascadeDeleteTests`, `VaultAccessEventTests`) rather than by adding methods to `VaultAPI.VaultConformanceSuite`, since the latter would require an ADR + `[INTEGRATION]` PR this task isn't scoped for. `compareRead`'s own conformance method already existed pre-task and continues to pass unmodified.

**Verify:** `Scripts/verify.sh VaultStore` — build + tests + boundary lint green. `Scripts/verify-integration.sh VaultStore` — no `*Conformance`/`*Integration` classes touched by this change beyond the pre-existing `SQLCipherVaultStoreConformanceTests` (still green); clean pass.

**Security/privacy self-audit:** Touches vault field/history/relationship data end-to-end (SQLCipher-encrypted at rest). `VaultAccessEvent` carries IDs/paths/ticket IDs only, no values, no logging — consistent with CLAUDE.md §7/§8. No network, no new entitlements, no `String` bridging of `SecureBytes`.

**Failure modes exercised in tests:** malformed batch (wrong-person field mid-batch, person deleted between ticket-mint and write) rolls back entirely; cascade delete verified via `compareRead`/`historyEntries`/`relationships` post-delete; date-range overlap edge cases (before-window, front-edge overlap, open-ended "ongoing" entries, open-ended queries).
