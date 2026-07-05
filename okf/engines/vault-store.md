---
type: engine
title: VaultStore
description: The Vault.xpc service implementation — SQLCipher store, key hierarchy, lock state. Every privileged call requires a verified PolicyTicket. Currently a placeholder stub.
tags: [engine, infrastructure-layer, vault, sqlcipher, xpc-service, stub]
implementation_status: scaffolded
---

# VaultStore

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the `Vault.xpc` service implementation ([../services/vault-service.md](../services/vault-service.md)) — SQLCipher store, key hierarchy, lock state. Every privileged call must require a *verified* `PolicyTicket` (verification via `PolicyKit`'s `TicketVerifier`, [../packages/policy-kit.md](../packages/policy-kit.md)); decrypted values must surface as `SecureBytes` only, never a bare `String`, matching `VaultAPI.FieldValue.string`'s shape ([../packages/vault-api.md](../packages/vault-api.md)).

## Current state

`Packages/VaultStore/Sources/VaultStore/VaultStore.swift` is a 4-line placeholder. No SQLCipher integration, key-hierarchy logic, or `VaultClient` conformance exists yet — `VaultAPI`'s `FakeVaultClient` (an in-memory actor, shipped in the `VaultAPI` package itself) is the only working `VaultClient` implementation in the repo today.

## Design intent (`docs/ARCHITECTURE.md` §6.2, §8)

Owns `vault.db` (SQLCipher AES-256), unwraps the master key via `LAContext`/Secure Enclave at unlock ([../architecture/key-hierarchy.md](../architecture/key-hierarchy.md)), holds it `mlock`ed and zeroizes on lock/idle, enforces single-writer-actor + WAL-mode transactional writes, and implements crypto-shred by destroying wrapped key copies rather than merely deleting rows.

## Allowed imports

Foundation, `VaultAPI`, `PolicyKit`, `Platform`.
