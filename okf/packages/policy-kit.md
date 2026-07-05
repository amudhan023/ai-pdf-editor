---
type: package
title: PolicyKit
description: Deterministic policy rules engine and PolicyTicket minting/verification — the one mandatory gate between any request and vault access.
tags: [package, policy, security, deterministic, hmac]
implementation_status: implemented
---

# PolicyKit

**Purpose:** the deterministic policy rules engine (`PolicyRules.decide`) and `PolicyTicket` minting/verification (`TicketMinter`/`TicketVerifier`, HMAC-SHA256). Rules are pure functions — adding I/O here would be an architecture violation. `ReplayGuard` (an in-memory actor) is the one deliberate exception: replay detection needs state across calls, but in-memory state ≠ I/O (no disk/network).

## Decision table (`PolicyRules.decide`)

Four ordered rows, first match wins (full table: `docs/specs/policy-decision-table.md`):

1. `sessionMode == .ephemeral && operation == .write` → `.deny` (nothing persists in ephemeral mode, reauth wouldn't change that).
2. `requiresConsent && !consentGranted` → `.deny` (future cloud-consent gate; default-deny, no reauth escape hatch).
3. `sensitivity == .sensitive && auth not fresh` → `.requireReauth` (distinct from `.deny` — a UX affordance, not a failure).
4. else → `.grant`.

`AuthFreshness.isFresh(at:within:)` compares `now - lastAuthenticatedAt` against a window (`PolicyRules.defaultAuthFreshnessWindow` = 5 minutes; callers may pass a stricter window, e.g. for `cryptoShred`).

## Ticket lifecycle

- `TicketMinter.mint(request:personID:scopedPaths:ttl:signingKey:...)` — always re-runs `PolicyRules.decide` and throws `TicketMintingError.notGranted` unless the result is `.grant`; never trusts a caller's prior decision. Signs `TicketClaims` (the ticket's fields minus signature) via `HMAC<SHA256>` with a canonical, sorted-keys, fixed-date-strategy JSON encoding — so minting and verification are guaranteed to encode identically.
- `TicketVerifier.verify(_:signingKey:now:)` — checks temporal validity, then HMAC match (`Result<Void, TicketVerificationError>`: `.expired`/`.invalidSignature`/`.replayed`).
- `ReplayGuard` — an `actor` tracking consumed ticket IDs for the process's lifetime; `consume(_:)` returns `true` only the first time an ID is seen. No eviction yet (documented known limitation — acceptable since tickets are short-TTL and no long-running consumer exists yet).

PolicyKit never fetches or stores signing key material itself — callers always supply the `SymmetricKey`; Keychain access is `Platform`'s job.

## Allowed imports

Foundation, `VaultAPI`, CryptoKit.

## Invariants

- Rules are pure functions of their arguments — no I/O, no randomness, no hidden state.
- Minting always re-derives the decision; never trusts a passed-in `.grant`.

Consumed by (currently stubs): `AutofillSession`, `IngestionSession`, `AutofillEngine`, `VaultManagerUI`. See [../architecture/security-model.md](../architecture/security-model.md) for how this fits the broader threat model.
