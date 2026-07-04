# DocEngineHost

**Purpose:** XPC client + PDFium adapter implementing PDFEngineAPI. The ONLY package that may link the PDF engine. Runs hostile-input parsing in DocEngine.xpc.

**Allowed imports:** Foundation, PDFEngineAPI, Platform (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh DocEngineHost` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** none yet — add them as they are learned (this section is the highest-leverage doc in the package).
