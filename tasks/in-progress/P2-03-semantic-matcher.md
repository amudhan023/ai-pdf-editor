# P2-03 — SemanticMatcher: Full Matching Ladder

**Owner:** claude-agent · **Branch:** task/P2-03-semantic-matcher · **Claimed:** 1f4498a106d99447a938ba6bb52b23ad3fcb90d1


**Epic:** E12 · **Primary package:** `Packages/AutofillEngine` · **Complexity:** L · **Priority:** Critical

## Goal
Complete the label→vault-path matcher: dictionary (P1-14) → embeddings → LLM tiebreak for ambiguous/composite cases, using page-text context around fields, with calibrated confidence output.

## Background
ARCHITECTURE.md §7.1 ladder + §4 (FormKnowledge consulted before ML — integration point stubs here, real store in P2-12). LLM rung uses FoundationModels via the generate endpoint; prompts contain labels and candidate paths, not vault values.

## Requirements
- Context assembly: field name/tooltip + nearby text runs (from P1-03 geometry) + section headers.
- Composite detection: "Full Name"/"Address" → multi-path decomposition plans (consumed by ValueFormatter).
- LLM tiebreak: constrained choice among top-k candidates only (never free generation of paths); hard timeout with graceful fallback to embedding rank.
- Calibrated confidence (high/medium/low) with per-rung attribution; deterministic given same inputs (temperature 0 / seeded).

## Dependencies
- P1-14, P2-01 (FormModel types), P1-12 (generate endpoint).

## Files Likely Affected
- `Packages/AutofillEngine/Sources/Matching/**`.

## Acceptance Criteria
- Bench on expected-field manifests: NFR-A1 ≥95% precision on top-200; report long-tail precision/recall; no regression vs P1-14 baseline.
- With Inference generate endpoint unavailable (Intel tier), ladder degrades to embeddings with correct confidence downgrade.

## Definition of Done
- Global DoD, plus: matcher accuracy added to CI gates.

## Testing Requirements
- Golden-set tests per rung; composite decomposition tests; degradation-path tests; determinism test.

## Documentation Updates
- `AutofillEngine/CLAUDE.md` ladder contract update; docs/specs/matching-confidence.md.

## Journal

**Orient:** Root CLAUDE.md; this task file; `Packages/AutofillEngine/CLAUDE.md`; `Matching/AliasMatcher.swift`/`AliasDictionary.swift`/`LabelNormalizer.swift` (P1-14's existing dictionary/embedding rungs, to compose rather than reimplement); `InferenceAPI/Generate.swift` (constrained-choice `GenerateRequest.candidates`/`chosenCandidateIndex` contract) and `FakeInferenceClient` (its `generate` echoes candidate 0, its `embed` is a deterministic FNV-1a-hash stand-in with no semantic meaning); `PDFEngineAPI/TextEditor.swift` (`TextRun` geometry) and `FormModel.swift` (`FormField`); `docs/specs/vault-schema.md` for real composite-decomposition targets (`identity.legal_name.{first,middle,last}`, `contact.address.{line1,line2,city,state,postal_code}`); `tasks/done/P1-14-embedding-alias-matcher.md`'s Journal for precedent (NFR-A1 "bench" = a unit test over the curated fixture, asserted ≥95% by construction — no real `Scripts/bench.sh` matcher suite exists).

**Plan:** No frozen-seam gap — `InferenceAPI.GenerateRequest`/`FormField`/`TextRun` already have everything needed. Add: `MatchSource.llm` + `MatchCandidate.confidence` (additive, in-package, not a frozen seam) to `AliasMatcher.swift`; `AliasMatcher.match` gains an additive `queryText` param so the embedding rung can be queried with page-text-enriched text while the dictionary rung stays exact-match on the bare label (avoids diluting rung-1 precision, which would regress the P1-14 baseline). New files: `Confidence.swift` (calibration), `CompositeDictionary.swift` + `Resources/composite_aliases.json` (checked before the dictionary rung — "full name"/"mailing address" entries; deliberately excludes bare "address", already a single-path `aliases.json` entry), `MatchContext.swift` (`MatchContext` + `ContextAssembler.assemble(field:pageTextRuns:)`, proximity + relative-font-size section-header heuristic), `SemanticMatcher.swift` (composite check -> `AliasMatcher` -> LLM tiebreak on ambiguous top-2 embedding candidates, hard timeout via `TaskGroup` race against `Task.sleep`, graceful fallback on timeout/throw/invalid-index).

**Implement:** Built as above. `Scripts/import-allowlist.txt` already permits everything used (Foundation/PDFEngineAPI/VaultAPI/InferenceAPI). A test-local `MockInferenceClient` (`Mock*`, not the shipped `Fake*`) wraps `FakeInferenceClient` for `embed`/other capabilities but lets tests control `generate`'s behavior (`.respond`/`.unavailable`/`.neverReturns`) — needed to exercise the hard-timeout and degradation paths deterministically, which `FakeInferenceClient`'s fixed always-succeeds `generate` can't do.

**A real fixture-derivation bug found via testing, not inspection:** while hand-deriving a label string whose `FakeInferenceClient`-embedded top-2 candidates would be ambiguous (for `SemanticMatcherTests`' LLM-tiebreak tests), an offline Python replica of `deterministicVector`'s FNV-1a-style hash used a mistyped multiplier constant (`0x0000010000000001B3`, 18 hex digits) instead of the real `0x0000_0100_0000_01B3` (16 hex digits) — produced wrong predicted scores/rankings, causing one authored test's expected confidence tier ("medium") to fail against the real Swift output ("high") on first `Scripts/verify.sh` run. Root-caused by writing a small throwaway Swift program replicating the *actual* algorithm instead of trusting the Python port, which also surfaced a second finding: `FakeInferenceClient`'s 8-dimensional, strictly non-negative vectors structurally bias cosine similarity upward — an exhaustive 200k-sample random-string search found no label scoring below ~0.89 against this package's `aliases.json`, meaning the `.medium`/`.low` confidence bands are unreachable through the fake in an end-to-end test. Resolved by keeping direct `MatchCandidate`-construction tests (`ConfidenceTests.swift`) for the threshold logic itself, and documenting the fake's limitation in `docs/specs/matching-confidence.md` rather than papering over it with a misleading "medium" test that happened to pass by coincidence.

**Verify:** `Scripts/verify.sh AutofillEngine` — OK (real `swift test` via full Xcode.app; 42 tests total, all new: `ConfidenceTests` x5, `CompositeDictionaryTests` x4, `ContextAssemblerTests` x7, `SemanticMatcherTests` x10). `Scripts/check-boundaries.sh AutofillEngine` — clean.

**Harden notes:** `AliasMatcher.match`'s new `queryText` param defaults to `label`, so every pre-existing P1-14 call site/test is behaviorally unchanged (verified: `AliasMatcherTests` untouched, still passes). `SemanticMatcher`'s LLM tiebreak never trusts a `chosenCandidateIndex` without range-checking it against the actual shortlist size first (CLAUDE.md §19: hallucinated/invalid paths must be structurally impossible) — an out-of-range or `nil` index is treated identically to a timeout (graceful fallback), covered by dedicated tests. Security/privacy self-audit: `GenerateRequest.prompt` carries only `context.assembledText` (field label/tooltip/page text) and candidate vault *paths* — never a vault value; no logging added.

## Handoff

**Status:** `SemanticMatcher`'s full matching ladder (composite -> dictionary -> embedding -> LLM tiebreak) is implemented, tested, and verified green. Requirements 1-4 and Acceptance Criterion 2 (degradation path) are met with real tests. Two items are honestly not done — flagged below, not silently skipped.

**What's done:**
- `Matching/Confidence.swift`, `CompositeDictionary.swift` + `Resources/composite_aliases.json`, `MatchContext.swift`, `SemanticMatcher.swift`; additive changes to `AliasMatcher.swift` (`.llm` source, `MatchCandidate.confidence`, `queryText` param).
- `docs/specs/matching-confidence.md` (calibration table + both known-limitation sections above); `AutofillEngine/CLAUDE.md` ladder section rewritten.
- Tests: golden-set (dictionary/composite short-circuit), LLM-tiebreak (validated pick, out-of-range index, nil/free-form index), degradation (generate unavailable, hard timeout), determinism, plus unit coverage for `Confidence`/`CompositeDictionary`/`ContextAssembler` in isolation.

**Deliberately not done (flagged, not silently skipped):**
1. **Acceptance Criterion 1's real bench** ("Bench on expected-field manifests: NFR-A1 ≥95% precision on top-200; report long-tail precision/recall; no regression vs P1-14 baseline"): no `Scripts/bench.sh` matcher-accuracy suite exists in this repo — this is a pre-existing gap inherited from P1-14 (which also had no such suite; its own Acceptance Criteria's "bench" was a unit test asserting 100% precision over the curated dictionary by construction), not newly introduced here. This task's tests are real golden-set/degradation/determinism tests, but proving ≥95% precision on an actual top-200 *labeled fixture manifest* with long-tail precision/recall reporting needs bench infrastructure (`Scripts/bench.sh` suite + `bench.yml` CI wiring) that doesn't exist yet for this package — same class of gap as this task's Definition of Done line ("matcher accuracy added to CI gates"), also not done for the same reason. Recommend a follow-up backlog task ("AutofillEngine: matcher-accuracy bench suite") once a labeled top-200 fixture manifest exists (itself blocked on fixture acquisition, `tasks/escalations/E-005-corpus-acquisition-gap.md`'s class of gap).
2. **P2-01's `FormField`/geometry integration**: `ContextAssembler.assemble(field:pageTextRuns:)` takes real `PDFEngineAPI.FormField`/`TextRun` types and is unit-tested against them directly, but nothing in `DocumentSession` or an autofill-session layer calls `SemanticMatcher` yet — that wiring is P2-05 (Fill Planner)'s job per the dependency graph, not this task's (this task's Files Likely Affected line only names `Matching/**`).

**Exact state:** branch `task/P2-03-semantic-matcher`, all work committed locally in the worktree at `/private/tmp/claude-501/-Users-amudhan-Desktop-project-ai-pdf-editor/e3790af4-14a0-460a-b4b4-8066910d910e/scratchpad/ai-pdf-editor-p2-03`, nothing pushed — coordinator handles push/PR. `Scripts/verify.sh AutofillEngine` OK, `Scripts/check-boundaries.sh AutofillEngine` clean.
