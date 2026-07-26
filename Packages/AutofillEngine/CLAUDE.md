# AutofillEngine

**Purpose:** Field discovery, matching ladder (dictionary -> embeddings -> LLM), value formatting, fill planning. Never writes to documents - sessions commit.

**Allowed imports:** Foundation, PDFEngineAPI, VaultAPI, InferenceAPI, PolicyKit, FormKnowledge (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh AutofillEngine` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Matching ladder (P1-14, completed P2-03):** `SemanticMatcher.match(context:)` is the entry point — composes `AliasMatcher` (dictionary/embedding rungs) rather than reimplementing them:
1. **Composite check** (`CompositeDictionary`, checked *before* the dictionary rung): a curated label like "full name"/"mailing address" resolves to a `.composite(CompositeMatch)` — an ordered multi-`FieldPath` decomposition plan, not a scored candidate. Deliberately excludes bare "address" (already a single-path `aliases.json` entry) — see the type's header doc.
2. **Dictionary rung** (`AliasDictionary`, exact match on `LabelNormalizer.normalize`d `context.label`, score 1.0, `.dictionary`, confidence always `.high`).
3. **Embedding rung** (cosine similarity over `InferenceClient.embed`, `.embedding`) — queried with `context.assembledText` (label + tooltip + section headers + nearby text, P2-03 Requirement 1), never with the dictionary-rung's bare label, so a context-diluted string can't cause a dictionary miss.
4. **LLM tiebreak rung** (`.llm`): only attempted when the top two embedding candidates are within `ambiguityMargin` (default 0.05) of each other. Calls `InferenceClient.generate` with the top-k candidate *paths* as `GenerateRequest.candidates` — constrained choice only (CLAUDE.md §19); a `nil` or out-of-range `chosenCandidateIndex` is rejected and falls back to the untouched embedding ranking, same as a timeout (hard-timeout via `Task.sleep` race, default 2s) or a thrown error (e.g. `capabilityUnavailable` on Intel tier).

Every `MatchCandidate` carries `source` (review UI provenance contract, CLAUDE.md §19) and a calibrated `confidence` (`MatchConfidence`: high/medium/low) — see `docs/specs/matching-confidence.md` for the calibration reasoning and known limitations. `ContextAssembler.assemble(field:pageTextRuns:)` builds a `MatchContext` from field geometry + P1-03 `TextRun`s (proximity + relative-font-size section-header heuristic); a caller not yet wired to real page geometry can construct `MatchContext` directly.

**Dictionary curation guide:** add a row to `Sources/AutofillEngine/Resources/aliases.json` — `vault_path` must already exist in `docs/specs/vault-schema.md` (never invent one here), `labels` is a map of language code -> variant strings; add locale variants only for fields likely to appear on non-English forms. Every variant is exercised by `AliasDictionaryTests.test_precisionBench_everyCuratedVariantResolvesCorrectly`, which fails if two different canonical fields' variants normalize to the same string. Composite entries follow the same shape in `Resources/composite_aliases.json` (`vault_paths`: ordered array, instead of a single `vault_path`).

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
