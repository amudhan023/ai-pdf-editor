---
type: service
title: Vault.xpc
description: The planned sandboxed vault service — sole owner of the encrypted DB and key material. Not yet scaffolded.
tags: [service, xpc, vault, encryption, planned]
implementation_status: planned
---

# Vault.xpc — `Services/VaultService`

## Current state

`Services/VaultService/` contains only a `README.md` — no `Sources/` directory, no target, nothing runnable yet. Everything below is design intent from `docs/ARCHITECTURE.md`, not implemented behavior.

## Trust posture (planned)

**The most privileged process in the system.** Sole owner of the vault database and key material; no network entitlement; exclusive access to the vault container; talks only to the main app's Policy & Trust layer (never directly to `AutofillSession`/`IngestionSession` — every request must arrive with a `PolicyTicket`, see [../architecture/security-model.md](../architecture/security-model.md)). On crash, the vault simply relocks — the DB is transactional, so there's no partial-write recovery story to build.

## Design intent

Owns the SQLCipher-encrypted `vault.db`, the Secure Enclave-rooted key hierarchy ([../architecture/key-hierarchy.md](../architecture/key-hierarchy.md)), lock state, and crypto-shred. Every read is field-scoped and logged — this process must never return a bulk plaintext dump; even the `compareRead` grant type exists specifically so ingestion's conflict detection never needs a full disclosure just to check "does this already exist."

This is the future implementation target for `VaultStore` ([../engines/vault-store.md](../engines/vault-store.md)), itself still a stub, which implements `VaultAPI`'s `VaultClient` protocol ([../packages/vault-api.md](../packages/vault-api.md)) against this process.
