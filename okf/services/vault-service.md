---
type: service
title: Vault.xpc
description: The sandboxed vault service — today a ping self-check skeleton executable; the real store/key-hierarchy logic lives in the VaultStore package.
tags: [service, xpc, vault, encryption]
implementation_status: scaffolded
---

# Vault.xpc — `Services/VaultService`

## Current state (P1-08)

`Services/VaultService/Sources/VaultService/main.swift` is a thin skeleton on the same pattern as `DocEngineService`'s (P0-05): it hosts an `XPCServiceHost<PingRequest, PingResponse>` on an anonymous listener and sends itself a ping, proving `Platform`'s transport types link and run in a standalone executable. What it **cannot** yet prove: a genuine cross-process connection from another process — that needs a real `.xpc` bundle target (see ADR-002 and [../architecture/process-topology.md](../architecture/process-topology.md)).

The vault store/key-hierarchy logic this service will eventually host already exists and is tested in the `VaultStore` package ([../engines/vault-store.md](../engines/vault-store.md)) — this executable stays a linkage/wiring proof only. Until the process split lands, the "master key only ever inside `Vault.xpc`" guarantee holds at the package/actor level, not the process level.

## Trust posture (design)

**The most privileged process in the system.** Sole owner of the vault database and key material; no network entitlement; exclusive access to the vault container; talks only to the main app's Policy & Trust layer (never directly to `AutofillSession`/`IngestionSession` — every request must arrive with a `PolicyTicket`, see [../architecture/security-model.md](../architecture/security-model.md)). On crash, the vault simply relocks — the DB is transactional, so there's no partial-write recovery story to build.

## Design

Owns the SQLCipher-encrypted `vault.db`, the Secure Enclave-rooted key hierarchy ([../architecture/key-hierarchy.md](../architecture/key-hierarchy.md)), lock state, and crypto-shred. Every read is field-scoped and logged — this process must never return a bulk plaintext dump; even the `compareRead` grant type exists specifically so ingestion's conflict detection never needs a full disclosure just to check "does this already exist."
