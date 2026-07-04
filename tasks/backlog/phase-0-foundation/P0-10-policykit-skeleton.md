# P0-10 — PolicyKit Skeleton: Rules Engine & Ticket Minting

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
