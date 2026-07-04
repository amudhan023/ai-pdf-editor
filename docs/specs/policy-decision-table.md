# PolicyKit Decision Table (v1)

Canonical source of the rules `PolicyRules.decide(_:now:authFreshnessWindow:)` implements (`Packages/PolicyKit/Sources/PolicyKit/PolicyRules.swift`). The code and this table must stay in sync — a rule change without a matching table update (or vice versa) is a defect in whichever side didn't move.

Rows are evaluated in order; the first matching row wins.

| # | `sessionMode` | `operation` | `requiresConsent` | `consentGranted` | `sensitivity` | auth fresh? | Decision | Why |
|---|---|---|---|---|---|---|---|---|
| 1 | `ephemeral` | `write` | any | any | any | any | `deny` | Ephemeral mode means nothing persists — reauth wouldn't change that, so this is checked before sensitivity/reauth. |
| 2 | any | any | `true` | `false` | any | any | `deny` | Future cloud-processing gate (PRD, no consumer yet): default-deny, and missing consent denies outright rather than degrading to `requireReauth` — there's no "reauth your way past missing consent." |
| 3 | any | any | (not both true+false) | | `sensitive` | **no** | `requireReauth` | Stale auth on sensitive-tier data asks for a fresher auth signal rather than failing outright (CLAUDE.md's "vault-locked is a normal state, not an error"). |
| 4 | (else) | | | | | | `grant` | Nothing above matched — the default is to allow. |

"Auth fresh?" = `AuthFreshness.isFresh(at:within:)`, i.e. `now - lastAuthenticatedAt <= authFreshnessWindow`. Default window: `PolicyRules.defaultAuthFreshnessWindow` = 300s (5 minutes); callers may pass a stricter window per call site (e.g. a tighter window for `cryptoShred`).

## Invariants this table guarantees (property-tested, `PolicyRulesPropertyTests.swift`)

- A `sensitive`-tier operation with stale auth **never** yields `.grant` (only `.requireReauth` — row 3 — since rows 1/2 could still independently force `.deny` first).
- An `ephemeral` `.write` **always** yields `.deny`, regardless of sensitivity or auth freshness.
- `requiresConsent && !consentGranted` **always** yields `.deny`, regardless of sensitivity or auth freshness.

## Ticket lifecycle (not a rule-table concern, but adjacent)

`PolicyRules.decide` answers "should this be allowed"; `TicketMinter.mint` is the only thing that turns a `.grant` into a signed, time-boxed `PolicyTicket` (HMAC-SHA256 over the ticket's claims minus signature — see `TicketClaims.canonicalPayload()`). `TicketVerifier.verify` checks expiry + signature; `ReplayGuard` (an in-memory actor, not part of the pure rule evaluation) rejects reuse of a ticket ID within a process's lifetime. A `.deny`/`.requireReauth` decision never reaches minting — `TicketMinter.mint` re-runs the same rules and throws `TicketMintingError.notGranted` rather than trusting a caller's prior decision, so there's no way to mint a ticket for an operation the rules would refuse.

## Known limitation

`ReplayGuard`'s consumed-ID set grows for the lifetime of the actor with no eviction — acceptable for now (tickets are short-TTL, and no long-running consumer exists yet), but a future task wiring this into a long-lived service (e.g. `Vault.xpc`) should add TTL-based eviction rather than assume unbounded memory is fine forever.
