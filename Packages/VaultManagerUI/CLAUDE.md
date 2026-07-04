# VaultManagerUI

**Purpose:** Vault window: profile management, field editing, sensitivity masking, unlock UX. Talks to the vault only through VaultAPI client protocols.

**Allowed imports:** Foundation, VaultAPI, PolicyKit (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh VaultManagerUI` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** none yet — add them as they are learned (this section is the highest-leverage doc in the package).
