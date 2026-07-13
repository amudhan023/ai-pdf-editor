# InferenceAPI

**Purpose:** Typed inference request/response contracts (ocr, classify, extract, embed, generate) + FakeInferenceClient. FROZEN SEAM: changes require an ADR.

**Allowed imports:** Foundation (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh InferenceAPI` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone. `InferenceConformanceSuite.verifyOCRReturnsRegions`'s fixture is a real base64-embedded PNG, not arbitrary bytes (ADR-012) — a real OCR adapter can only honestly satisfy "returns >=1 region" for a decodable image containing text; don't revert to a synthetic byte literal when touching this file.
