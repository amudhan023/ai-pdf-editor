# AutofillEngine

**Purpose:** Field discovery, matching ladder (dictionary -> embeddings -> LLM), value formatting, fill planning. Never writes to documents - sessions commit.

**Allowed imports:** Foundation, PDFEngineAPI, VaultAPI, InferenceAPI, PolicyKit, FormKnowledge (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh AutofillEngine` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
