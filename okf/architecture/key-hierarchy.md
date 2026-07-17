---
type: security
title: Key Hierarchy
description: The Secure Enclave-rooted key hierarchy that protects the vault at rest — master key, derived keys, recovery code, crypto-shred. Implemented in VaultStore; the Vault.xpc process boundary is pending.
tags: [security, encryption, secure-enclave, key-management, vault]
implementation_status: partial
---

# Key Hierarchy

Design from `docs/ARCHITECTURE.md` §6.2. **Implemented in `VaultStore`** (P1-08/P1-09 — `KeyHierarchy/`: `SecureEnclaveKeyBox`, `MasterKeyManager`, `KeychainStore`, `RecoveryCode`, `DerivedKeys`; `Lock/VaultLockController` for unlock/auto-lock — see [../engines/vault-store.md](../engines/vault-store.md)). Marked *partial* because the process-level half of the guarantee — the master key existing only inside a real `Vault.xpc` process — awaits the `.xpc` bundle split; today the store runs in-process.

```
Secure Enclave key (non-exportable, biometry-bound policy)
  └─ unwraps at unlock → Vault Master Key (256-bit, generated once, wrapped copy in Keychain)
       ├─ → DB Key → SQLCipher (vault database)
       ├─ → Attachment Keys (per-file AES-256-GCM)
       └─ → Backup Key (local encrypted backups)
Recovery Code (user-held, printed once) — wraps a copy of the Master Key, survives biometry reset
```

**Unlock:** `LAContext` success (via `Platform`'s `LocalAuthenticator`) → Secure Enclave unwraps the master key → intended to be handed only to `Vault.xpc`, held in `mlock`ed memory, zeroized on lock/idle timeout (`VaultLockController` implements lock/auto-lock today).

**Crypto-shred (PRD FR-2.6, "one-click secure erase"):** destroy the wrapped master-key copies (Keychain + recovery-wrapped) → the entire vault, attachments, and backups become unrecoverable noise instantly. Implemented in `VaultStore` as wrapped-key destruction, matching `VaultAPI.VaultClient.cryptoShred(_:ticket:)`'s protocol-level commitment ("the person and all its data become unreadable afterward").

**Sensitive-tier gate:** reads of `.sensitive`-tier fields require the last user-presence check to be fresher than a configurable window, else re-auth is required — `PolicyKit`'s `PolicyRules` row 3 (`sensitive` + stale auth → `requireReauth`), enforced deterministically (see [security-model.md](security-model.md)), with the biometric re-auth prompt now available via `LocalAuthenticator`.
