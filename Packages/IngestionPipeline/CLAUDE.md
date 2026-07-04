# IngestionPipeline

**Purpose:** Document ingestion stage graph: normalize -> OCR -> classify -> extract -> map -> conflict-detect. Emits ExtractionCandidates only - never writes to the vault.

**Allowed imports:** Foundation, PDFEngineAPI, VaultAPI, InferenceAPI (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh IngestionPipeline` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** none yet — add them as they are learned (this section is the highest-leverage doc in the package).
