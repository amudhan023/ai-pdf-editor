---
type: security
title: Key Hierarchy
description: The Secure Enclave-rooted key hierarchy that protects the vault at rest — master key, derived keys, recovery code, crypto-shred.
tags: [security, encryption, secure-enclave, key-management, vault]
implementation_status: planned
---

# Key Hierarchy

Design from `docs/ARCHITECTURE.md` §6.2. **Not yet implemented** — this depends on `VaultStore` and `Platform`'s Keychain/LAContext wrappers, both still stub packages (see [module-map.md](module-map.md)); nothing described below exists in code yet.

```
Secure Enclave key (non-exportable, biometry-bound policy)
  └─ unwraps at unlock → Vault Master Key (256-bit, generated once, wrapped copy in Keychain)
       ├─ → DB Key → SQLCipher (vault database)
       ├─ → Attachment Keys (per-file AES-256-GCM)
       └─ → Backup Key (local encrypted backups)
Recovery Code (user-held, printed once) — wraps a copy of the Master Key, survives biometry reset
```

**Unlock:** `LAContext` success → Secure Enclave unwraps the master key → handed only to `Vault.xpc`, held in `mlock`ed memory, zeroized on lock/idle timeout.

**Crypto-shred (PRD FR-2.6, "one-click secure erase"):** destroy the wrapped master-key copies (Keychain + recovery-wrapped) → the entire vault, attachments, and backups become unrecoverable noise instantly. `VaultAPI.VaultClient.cryptoShred(_:ticket:)` already commits to this observable effect at the protocol level ("the person and all its data become unreadable afterward") even though the real key-destruction implementation doesn't exist yet.

**Sensitive-tier gate:** reads of `.sensitive`-tier fields require the last user-presence check to be fresher than a configurable window, else re-auth is required — this is `PolicyKit`'s `PolicyRules` row 3 (`sensitive` + stale auth → `requireReauth`), which *is* implemented and enforced deterministically today (see [security-model.md](security-model.md)), even though the biometric re-auth prompt itself and the key unwrap it gates are not yet built.
