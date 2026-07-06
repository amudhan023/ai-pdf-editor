# P1-15 — Audit Log (Hash-Chained, Append-Only)

**Epic:** E14 · **Primary package:** `Packages/AuditLog` · **Complexity:** M · **Priority:** High

## Goal
Tamper-evident local audit log consuming domain events (vault access, ingestions, fills, network events) — the data source for the Privacy Dashboard (P3-03).

## Background
ARCHITECTURE.md §6.3/FR-5.2. Entries carry IDs, field paths, ticket IDs, hashes — never values or document content (enforced at the type level: the entry type has no free-form value slot).

## Requirements
- Append-only store with per-entry hash chaining (tamper detection on read); rotation with chain continuity; bounded size with oldest-segment archival.
- Typed event schema: `vaultRead/vaultWrite/ingestionCommitted/fillCommitted/networkEvent/authEvent` etc.
- Subscription to the domain event bus; synchronous write guarantee for privileged events (a fill isn't committed until its audit entry is durable).
- Read API with filtering (for dashboard) + chain-verification routine.

## Dependencies
- P0-01 (event bus lives in Platform; add it here if not present — mark `[INTEGRATION]` in that case).

## Files Likely Affected
- `Packages/AuditLog/Sources/**`; possibly `Packages/Platform/Sources/Events/**`.

## Acceptance Criteria
- Manual byte-flip in the log file is detected by verification.
- Type system rejects an event carrying a value payload (compile-time test via API design).

## Definition of Done
- Global DoD.

## Testing Requirements
- Chain integrity property tests; rotation tests; durability test (crash between event and ack).

## Documentation Updates
- Package `CLAUDE.md`: "no values, ever" invariant; event schema doc.
