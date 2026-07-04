# PolicyKit

**Purpose:** Deterministic policy rules engine and PolicyTicket minting/verification. Pure functions over typed inputs - adding I/O here is an architecture violation.

**Allowed imports:** Foundation, VaultAPI (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh PolicyKit` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** none yet — add them as they are learned (this section is the highest-leverage doc in the package).
