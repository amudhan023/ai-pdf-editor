# P1-15 — Audit Log (Hash-Chained, Append-Only)

**Owner:** claude-agent · **Branch:** task/P1-15-audit-log-gaps · **Claimed:** 84f384a10ff55b66bfa841e1a72db78c3619396e

**Note:** an earlier PR #44 (merged 2026-07-06) implemented the base chain/rotation store but only covered a subset of this task's requirements (no archival, filtering, metadata value-safety, or event-bus subscription seam) and its own "move to done" commit was left on an orphaned branch, never merged to `main` — that's why this task file was still in `backlog/` for this iteration to claim. This PR finishes the remaining requirements.

**Epic:** E14 · **Primary package:** `Packages/AuditLog` `[INTEGRATION]` (+ `Packages/Platform`) · **Complexity:** M · **Priority:** High

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

## Journal

### Orient
- Read root CLAUDE.md, this task file, `Packages/AuditLog/CLAUDE.md`, `Packages/Platform/CLAUDE.md`, existing `AuditLog.swift`/`AuditLogTests.swift`.
- Phase-0 backlog (P0-06, P0-07) is blocked: both depend transitively on P0-03, which is still `in-progress/` (follow-up items open, not moved to `done/`). No unblocked Critical/High task exists there.
- Phase-1: P1-01/03/04/05/06 blocked on P0-06/07 or each other; P1-13's text-layer-write half needs P1-16 (in-progress). P1-15's only dependency, P0-01, is `done/`, and `Packages/AuditLog` is unclaimed. Selected P1-15.
- AuditLog already has (from prior work, e.g. #46): actor-based store, per-entry hash chaining, rotation, `verifyChain`, typed `AuditEventType`. Gaps vs. this task's requirements: no bounded-size/archival, no filtered read API, `metadata: [String: String]?` is a real value-payload loophole (nothing stops a caller stuffing document/vault content in there), no event-bus subscription surface, no durability test.
- Platform's own CLAUDE.md already claims "domain event bus" as part of its purpose, but no such type exists yet (confirmed via grep) — this task's Dependencies line says to add it there if absent, marking this `[INTEGRATION]`.

### Plan
1. `Packages/AuditLog`: replace free-form `[String: String]?` metadata with a closed `AuditMetadataKey` enum + `AuditMetadataValue` enum (`.count(Int)`, `.flag(Bool)`, `.durationMs(Int)`, `.sha256(String)` — the last validated to be exactly 64 hex chars at construction) carried as `[AuditMetadataEntry]?` (sorted by key for deterministic hashing). This is what makes "type system rejects a value payload" true structurally, not just by convention — closes acceptance criterion 2.
2. Add bounded size: `maxLiveSegments` param; oldest segment(s) get moved into a `archive/` subdirectory (not deleted) once exceeded. `allEntries`/`verifyChain`/tail-hash search read both dirs, sorted by the same global segment index, so chain continuity is unaffected by which folder a segment physically sits in.
3. Add `AuditEntryFilter` (eventTypes/ticketID/fieldPathPrefix/date range) + `entries(matching:)` read API for the future Privacy Dashboard (P3-03).
4. Add a bus-agnostic subscription seam: `AuditableEvent` protocol (maps to eventType/fieldPath/ticketID/metadata) + `AuditLogStore.subscribe<S: AsyncSequence>(to:) where S.Element: AuditableEvent`, appending (and thus durably writing) each event before advancing — this is what gives "a fill isn't committed until its audit entry is durable" for any future caller that awaits the subscribed stream's producer.
5. `Packages/Platform`: add a minimal `DomainEventBus` actor (`DomainEvent` enum + `DomainEventSubscriber` protocol, `publish` awaits all subscribers) — the missing P0-01 infra the task calls out. Deliberately does **not** import AuditLog and AuditLog does **not** import Platform: per CLAUDE.md §3.7 a new cross-package dependency needs its own ADR, and the actual glue (conforming a `DomainEvent` handler to `AuditableEvent`) belongs in whatever composition root/session first needs both — filing that as a follow-up task rather than improvising the dependency now.
6. Tests: chain/rotation (existing, keep green), archival-triggers-move test, filtered-read test, metadata-value-rejection test (only closed enum cases compile), subscribe-durability test (stream of fake `AuditableEvent`s each durably appended in order), tamper test extended to cover an archived segment.
7. Update `Packages/AuditLog/CLAUDE.md` (metadata invariant, event schema, archival/subscribe API) and `Packages/Platform/CLAUDE.md` (new `DomainEventBus`).
8. File a follow-up backlog task for the Platform-bus-to-AuditLog adapter wiring (Step 9 improvement, not blocking this PR).

No frozen seam, entitlement, or new package dependency required — proceeding without escalation.
