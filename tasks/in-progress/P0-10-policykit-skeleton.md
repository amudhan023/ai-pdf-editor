# P0-10 — PolicyKit Skeleton: Rules Engine & Ticket Minting

**Owner:** claude-code · **Branch:** task/P0-10-policykit-skeleton · **Claimed:** 0379fe731449107d047eee40fa9152cae1b32661

**Epic:** E14 · **Primary package:** `Packages/PolicyKit` · **Complexity:** M · **Priority:** Critical

## Goal
Deterministic policy engine that mints `PolicyTicket`s: pure-function rules over typed inputs (operation, field paths, sensitivity, auth freshness, session mode) → grant/deny/require-reauth.

## Background
ARCHITECTURE.md driver 4 and §3.2: no vault access without a ticket; rules are code-reviewed logic, never model output. Landing this *before* any consumer exists prevents "temporary bypass" architecture rot (ROADMAP.md §4).

## Requirements
- Rule inputs/outputs as value types; rules: sensitivity gating (NFR-A4), auth-freshness window, ephemeral-mode (deny persist), consent flags (future cloud gate, default-deny).
- Ticket minting + verification (HMAC over operation scope, short TTL); replay rejection.
- Full decision table documented and property-tested; zero I/O in the package.

## Dependencies
- P0-09.

## Files Likely Affected
- `Packages/PolicyKit/Sources/**`, `Tests/**`.

## Acceptance Criteria
- Decision-table tests cover every rule branch; a Sensitive-tier read with stale auth yields `requireReauth`, never `grant`.
- Expired/tampered/replayed tickets fail verification.

## Definition of Done
- Global DoD, plus: decision table published in docs/specs/policy-decision-table.md.

## Testing Requirements
- Property-based tests (random operation/tier/freshness combos never produce unsafe grants); ticket crypto unit tests.

## Documentation Updates
- Package `CLAUDE.md` invariant: "rules are pure functions; adding I/O here is an architecture violation."

---
## Journal

**Plan:** `PolicyRequest`/`AuthFreshness`/`SessionMode` (value types) → `PolicyRules.decide` (pure decision-table function, order-sensitive: ephemeral-write-deny and consent-default-deny checked before sensitivity/reauth, since neither should be overridable by a fresher auth signal) → `TicketMinter`/`TicketVerifier` (HMAC-SHA256 via CryptoKit over a canonical, sorted-keys JSON encoding of the ticket's claims minus signature) → `ReplayGuard` (in-memory actor, the one stateful piece).

**Done:**
- `PolicyDecision`, `PolicyRequest`/`AuthFreshness`/`SessionMode`, `PolicyRules.decide` (4-row decision table, documented in both the source doc comment and `docs/specs/policy-decision-table.md`).
- `TicketClaims` (private canonical-encoding type — `FieldPath` isn't `Codable`, so scoped paths are captured via `.description`), `TicketMinter.mint` (re-runs the rules and refuses to mint unless `.grant`), `TicketVerifier.verify` (expiry + HMAC via `HMAC<SHA256>.isValidAuthenticationCode`, constant-time by construction), `ReplayGuard` (actor, in-memory, process-lifetime only).
- Added `CryptoKit` to `Scripts/import-allowlist.txt` for `PolicyKit` — a system framework (like `Foundation`), not a new third-party SPM dependency, so no ADR needed per CLAUDE.md §17's dependency-approval process (that's for external packages).
- Tests: `PolicyRulesDecisionTableTests` (one test per decision-table row, both directions where relevant — e.g. row 3's exact-boundary case), `PolicyRulesPropertyTests` (2000 seeded-random combinations asserting the three safety invariants never break), `TicketCryptoTests` (mint→verify round-trip, refuse-to-mint-when-denied, expired/tampered-signature/tampered-claim/wrong-key/replay — all the acceptance-criteria failure modes, each as its own test rather than one big one).
- `Scripts/verify.sh PolicyKit` → `OK`. `swiftlint` → 0 serious violations (fixed real hits: two force-unwraps left as warnings in test code, which CLAUDE.md §4 explicitly permits, and renamed `a`/`b` to `firstConsumed`/`secondConsumed` in one test for identifier clarity).
- HARDEN: removed a speculative, untested, uncalled `ReplayGuard.forget(_:)` I'd written "for future hygiene" — no caller, no test, so it was dead code; the underlying concern (unbounded growth) is instead recorded as a known limitation in the decision-table doc and package `CLAUDE.md`, for a future task to actually address when it has a real consumer to design against.
- Docs: `docs/specs/policy-decision-table.md` (full table + invariants + ticket-lifecycle note + known limitation), package `CLAUDE.md` updated (18 lines).

**Security self-audit:** mints/verifies capability tokens; never logs decisions, tickets, or key material; never fetches/stores signing keys itself (caller-supplied `SymmetricKey`, per the package's zero-I/O invariant); no network APIs. This is exactly the kind of change CLAUDE.md §21 flags as security-touching — **this PR requests human review, not self-merging**, even though `PolicyKit` isn't marked `[INTEGRATION]` or `*API` in its task header.

**Acceptance criteria status:**
- "Decision-table tests cover every rule branch; a Sensitive-tier read with stale auth yields `requireReauth`, never `grant`": ✅ — `PolicyRulesDecisionTableTests` + `PolicyRulesPropertyTests` (2000 random trials, zero unsafe grants).
- "Expired/tampered/replayed tickets fail verification": ✅ — `TicketCryptoTests` covers expired, tampered signature, tampered claim, wrong key, and replay (via `ReplayGuard`), each independently.
