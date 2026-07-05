# AutofillEngine

**Purpose:** Field discovery, matching ladder (dictionary -> embeddings -> LLM), value formatting, fill planning. Never writes to documents - sessions commit.

**Allowed imports:** Foundation, PDFEngineAPI, VaultAPI, InferenceAPI, PolicyKit, FormKnowledge (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh AutofillEngine` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Matching ladder (P1-14):** `AliasMatcher.match(label:)` tries the dictionary rung first (`AliasDictionary`, exact match on `LabelNormalizer.normalize`d text, score 1.0, `.dictionary`); on a miss it falls through to the embedding rung (cosine similarity over `InferenceClient.embed`, `.embedding`) against the dictionary's own known vault paths. The LLM rung lands in P2-03. Every candidate carries `source` — the review UI's provenance contract (CLAUDE.md §19) depends on it.

**Dictionary curation guide:** add a row to `Sources/AutofillEngine/Resources/aliases.json` — `vault_path` must already exist in `docs/specs/vault-schema.md` (never invent one here), `labels` is a map of language code -> variant strings; add locale variants only for fields likely to appear on non-English forms. Every variant is exercised by `AliasDictionaryTests.test_precisionBench_everyCuratedVariantResolvesCorrectly`, which fails if two different canonical fields' variants normalize to the same string.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
