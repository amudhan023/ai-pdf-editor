---
type: engine
title: VaultStore
description: The real SQLCipher-backed VaultClient — key hierarchy, lock/auth, crypto-shred, attachments, backups, and the domain-event→audit-log adapter. Runs in-process today; the Vault.xpc split is pending.
tags: [engine, infrastructure-layer, vault, sqlcipher, xpc-service]
implementation_status: implemented
---

# VaultStore

**Purpose:** the `Vault.xpc` service implementation ([../services/vault-service.md](../services/vault-service.md)) — SQLCipher store, key hierarchy, lock state. Every privileged call requires a *verified* `PolicyTicket` (verification via `PolicyKit`'s `TicketVerifier`, [../packages/policy-kit.md](../packages/policy-kit.md)); decrypted values surface as `SecureBytes` only, never a bare `String`, matching `VaultAPI.FieldValue.string`'s shape ([../packages/vault-api.md](../packages/vault-api.md)).

## Current state (P1-08, P1-09, P1-10, P1-18)

Substantively implemented across `Packages/VaultStore/Sources/VaultStore/`:

- **`SQLCipherVaultStore`** — an `actor` conforming to `VaultAPI.VaultClient` (GRDB + SQLCipher), with structural ticket enforcement mirroring `FakeVaultClient`'s. Full field/person/history/relationship CRUD, `compareRead`, and crypto-shred.
- **`TicketVerifyingVaultClient`** — a separate, composable layer adding cryptographic ticket verification (signature, expiry, replay) in front of any `VaultClient`.
- **`KeyHierarchy/`** — `SecureEnclaveKeyBox`, `MasterKeyManager`, `KeychainStore`, `RecoveryCode`, `DerivedKeys`, `KeyWrappingProvider`: the Secure Enclave-rooted hierarchy from [../architecture/key-hierarchy.md](../architecture/key-hierarchy.md), including crypto-shred by wrapped-key destruction.
- **`Lock/`** — `VaultLockController` (lock/unlock, Touch ID via `Platform`'s `LocalAuthenticator`, auto-lock on idle), `LockedBytes`, `VaultLockEvent`.
- **`Operations/`** — `BatchFieldAcceptance` (the ingestion accept-set commit shape), `HistoryDateRangeQuery`; plus `VaultAccessEvent` emission.
- **`Attachments/AttachmentStore`**, **`Backup/BackupManager`** — per-file encrypted attachments and local encrypted backups.
- **`Audit/DomainEventAuditAdapter`** (P1-18) — durably appends `Platform.DomainEventBus` events to `AuditLog` ([../packages/audit-log.md](../packages/audit-log.md)).

**Boundary caveat:** all of this runs *in-process* today. `Services/VaultService` is still a ping self-check skeleton — the real `Vault.xpc` process boundary (and with it the "master key only ever in `Vault.xpc`, `mlock`ed" guarantee at the *process* level) awaits the `.xpc` bundle work (see [../architecture/process-topology.md](../architecture/process-topology.md)).

## Design (`docs/ARCHITECTURE.md` §6.2, §8)

Owns `vault.db` (SQLCipher AES-256), unwraps the master key via `LAContext`/Secure Enclave at unlock, holds it locked in memory and zeroizes on lock/idle, enforces single-writer-actor + WAL-mode transactional writes, and implements crypto-shred by destroying wrapped key copies rather than merely deleting rows.

## Allowed imports

Foundation, `VaultAPI`, `PolicyKit`, `Platform`, GRDB/SQLCipher (Infra-tier privilege).
