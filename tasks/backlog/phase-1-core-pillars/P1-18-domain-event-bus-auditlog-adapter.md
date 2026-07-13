# P1-18 — Wire Platform's DomainEventBus to AuditLog

**Epic:** E14 · **Primary package:** first session/composition-root package that needs both (e.g. `DocumentSession`, `AutofillSession`, or `App`) `[INTEGRATION]` · **Complexity:** S · **Priority:** Medium

## Goal
Connect `Platform.DomainEventBus` (P1-15) to `AuditLog.AuditLogStore` so privileged operations (vault reads/writes, ingestion, fills, auth) actually produce durable audit entries at runtime, not just in tests.

## Background
P1-15 added `Platform.DomainEventBus` (actor, fan-out `publish`/`subscribe`) and `AuditLog.AuditLogStore.subscribe<S: AsyncSequence>(to:) where S.Element: AuditableEvent`, deliberately without either package depending on the other — CLAUDE.md §3.7 requires an ADR for any *new* cross-package dependency, and the actual adapter (conforming `Platform.DomainEvent` handling to `AuditLog.AuditableEvent`) belongs in whichever package first has a legitimate reason to depend on both, not in either leaf package pre-emptively.

## Requirements
- A small adapter type (in the consuming package) that maps `Platform.DomainEvent` cases to `AuditLog.AuditableEvent`/`AuditLogStore.append` calls, or bridges `DomainEventBus` into an `AsyncStream` consumed by `AuditLogStore.subscribe`.
- Confirm whichever package ends up owning this adapter is allowed (by `Scripts/import-allowlist.txt`) to depend on both `Platform` and `AuditLog`; update the allowlist + `Package.swift` deps in the same PR if not (this is the "new cross-package dependency" — file/reference an ADR if the chosen package's existing architecture role doesn't already justify it).
- Real call sites (at least one) publish a `DomainEvent` for a privileged operation and the corresponding audit entry is verifiably durable before the operation is reported as committed.

## Dependencies
- P1-15.

## Files Likely Affected
- Wherever the first real session/composition root wiring vault/fill/ingestion events lives.

## Acceptance Criteria
- An integration test publishes a `DomainEvent` and asserts a matching, chain-valid `AuditEntry` exists afterward.

## Definition of Done
- Global DoD (tasks/README.md).

## Testing Requirements
- `*IntegrationTests` class covering the publish → durable-append path (P0-15 tier).

## Documentation Updates
- The owning package's `CLAUDE.md` (adapter's existence and invariant: still no values crossing the bus).
