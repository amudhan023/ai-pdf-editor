# ADR-011 — VaultStore Depends on AuditLog (DomainEventBus → AuditLog Adapter)

**Status:** Accepted · **Task:** P1-18 · **Amends:** nothing (new dependency edge, not a frozen-seam type change)

## Context
P1-15 added `Platform.DomainEventBus` (fan-out `publish`/`subscribe`) and `AuditLog.AuditLogStore.subscribe<S: AsyncSequence>(to:) where S.Element: AuditableEvent`, deliberately keeping `Platform` and `AuditLog` decoupled from each other — CLAUDE.md §3.7 requires an ADR before adding any new cross-package dependency, so neither leaf package was allowed to reach for the other pre-emptively. Both packages' doc comments name the adapter's future home as "whichever package first needs both wired together."

`Packages/VaultStore` is that package: `VaultLockController` already owns the vault's lock/unlock state machine and `SQLCipherVaultStore.emitAccess` already fires a `VaultAccessEvent` on every privileged read/write/compareRead/cryptoShred call (P1-10) — the exact "privileged operations... actually produce durable audit entries at runtime" surface P1-18 targets. `VaultStore` already depends on `Platform` (for `LocalAuthenticating`/`mlock` primitives), so `AuditLog` is the one new edge.

## Decision
Add `AuditLog` as a dependency of `Packages/VaultStore` (`Package.swift` + `Scripts/import-allowlist.txt`). New file `Sources/VaultStore/Audit/DomainEventAuditAdapter.swift`:
- `extension DomainEvent: @retroactive AuditableEvent` — maps `Platform.DomainEvent` cases to `AuditLog`'s `AuditEventType`/field path/ticket ID. `VaultOperation.compareRead` audits as `.vaultRead` (never reveals a value, ARCHITECTURE.md §5.1) and `.cryptoShred` audits as `.vaultWrite` (destructive write), since `DomainEvent` only distinguishes read/write.
- `AuditLogDomainEventSubscriber: DomainEventSubscriber` — appends each event to an injected `AuditLogStore` inside `handle(_:)`, so `DomainEventBus.publish`'s "await every subscriber" guarantee makes the audit append durable before `publish` returns.
- `SQLCipherVaultStore` gains an optional `domainEventBus: DomainEventBus?` init parameter (default `nil`, so every existing caller/test is unaffected) and `emitAccess` becomes `async throws`, publishing a mapped `DomainEvent` after yielding its existing local `VaultAccessEvent`.

This is additive at every existing call site: `emitAccess`'s 16 callers (all already inside `async throws` functions) gained `try await`; no `VaultClient` protocol signature changed, so `VaultAPI` (frozen seam) is untouched.

## Consequences
- `VaultStore` can now import `AuditLog`; nothing in the reverse direction — `AuditLog` still has zero dependencies, matching its package `CLAUDE.md`'s "Foundation" import list, unchanged by this ADR.
- A privileged operation with no `domainEventBus` wired (the default, and every current call site except the new `DomainEventAuditIntegrationTests` test) has no durable-audit side effect — this ADR only builds the adapter and the plumbing point; wiring a real, persistent `AuditLogStore` + `DomainEventBus` into the composition root (`App/` or `Services/VaultService`) is a follow-up task once those exist for real (currently `Services/VaultService` is a thin XPC skeleton, P0-07's job to give it a real host).
- Per ADR-008, this new-dependency PR is self-mergeable once this ADR is present in the diff and `ci-status` is green — no separate human-approval click required.
