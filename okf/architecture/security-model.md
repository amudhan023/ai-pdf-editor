---
type: security
title: Security Model
description: The threat model, PolicyTicket mediation, SecureBytes discipline, and process-isolation controls that make Vaultform's privacy claims structural rather than promised.
tags: [security, privacy, policy-ticket, secure-bytes, sandboxing]
implementation_status: partial
---

# Security Model

## Threat model (summary, `docs/ARCHITECTURE.md` §6.1)

| Threat | Primary control |
|---|---|
| Malicious PDF exploiting the parser | `DocEngine.xpc` process isolation, no entitlements, per-document instance |
| Stolen Mac, powered off | FileVault + vault encryption at rest; keys in Secure Enclave |
| Stolen Mac, logged in, vault locked | Vault key unwrap requires `LAContext` (Touch ID/password); auto-lock |
| Malware reading the vault DB file | SQLCipher — ciphertext without the SE-wrapped key |
| Same-user code execution + memory scraping | Partially mitigated: minimized plaintext window (field-scoped grants, zeroization); honestly documented as residual risk |
| Our own code exfiltrating data | No-network services, audited network events, third-party audit posture |
| Shoulder surfing / UI leakage | Sensitive-tier masking, transient pasteboard, screenshot-excluded vault windows |
| Compromised model pack | Signed + checksummed packs; `Inference.xpc` refuses unverified models |

## Structural controls that exist in code today

- **PolicyTicket mediation** (implemented — [packages/policy-kit.md](../packages/policy-kit.md), [packages/vault-api.md](../packages/vault-api.md)): every `VaultClient` operation except `lockState()` requires a `PolicyTicket`. `PolicyTicket` is operation-scoped (`VaultOperation`: read/write/compareRead/cryptoShred), person-scoped, path-scoped (`FieldPath.isPrefix(of:)` lets a ticket cover a whole section), and time-boxed (`isTemporallyValid(at:)`). Minting always re-runs `PolicyRules.decide` and refuses unless the result is `.grant` — no caller can mint a ticket for an operation the rules would deny. Verification checks expiry and an HMAC-SHA256 signature over the ticket's claims (`TicketVerifier`); `ReplayGuard` (an in-memory actor) additionally rejects reuse of a ticket ID within the process's lifetime.
- **`SecureBytes`** (implemented — [packages/vault-api.md](../packages/vault-api.md)): `FieldValue.string` carries `SecureBytes`, never a bare `String`, forcing every hop between `Vault.xpc` and the eventual UI/document write through one greppable `exposeAsPlaintext()` seam. Its `description`/`debugDescription` are redacted by construction so an accidental `print`/log-interpolation can't leak a value. Documented honestly as a *structural/wire* discipline, not a memory-hardening primitive — no `mlock` or deinit-driven zeroization at this layer; that's `VaultStore`/`Platform`'s job once built.
- **Deterministic policy rules** (implemented): `PolicyRules.decide` is a pure function of `(request, now, authFreshnessWindow)` — no I/O, no randomness. Four ordered rows: ephemeral-mode writes always deny; missing consent always denies; stale auth on sensitive-tier data requires reauth (not an outright deny); otherwise grant. Table lives in `docs/specs/policy-decision-table.md` and must stay in sync with the code.

## Controls that are design intent, not yet code

Process isolation (App Sandbox + Hardened Runtime on all four executables, no network entitlement on any XPC service), the Secure Enclave key hierarchy, crypto-shred, and pasteboard-transient-type handling are all described in `docs/ARCHITECTURE.md` §6 but depend on packages (`VaultStore`, `Platform`'s Keychain/LAContext wrappers, `App`) that are still stubs or unscaffolded — see [key-hierarchy.md](key-hierarchy.md) and [module-map.md](module-map.md).

## Constitutional backing

Constitution Article 11 ("Security boundaries are structural") is the immutable rule underneath all of this: PolicyTickets, process isolation, and `SecureBytes` may never be weakened "for now," in any circumstance. Article 1 ("Data sovereignty") is the equally immutable backing for the no-network rule.
