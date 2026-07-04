# PolicyKit

**Purpose:** Deterministic policy rules engine (`PolicyRules.decide`, decision table in `docs/specs/policy-decision-table.md`) and `PolicyTicket` minting/verification (`TicketMinter`/`TicketVerifier`, HMAC-SHA256). **Rules are pure functions — adding I/O here is an architecture violation.** `ReplayGuard` (in-memory actor) is the one deliberate exception: replay detection needs state, but "state" ≠ "I/O" (no disk/network) — see its doc comment.

**Allowed imports:** Foundation, VaultAPI, CryptoKit (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh PolicyKit` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- PolicyKit never fetches or stores signing key material itself — callers always supply the `SymmetricKey`. Keychain access is Platform's job, not this package's.
- `TicketMinter.mint` always re-runs `PolicyRules.decide` and refuses (throws) unless the result is `.grant` — never trusts a caller's prior decision.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:**
- `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
- `ReplayGuard`'s consumed-ID set has no eviction yet (fine for now — no long-running consumer exists; see the decision-table doc's "Known limitation").
