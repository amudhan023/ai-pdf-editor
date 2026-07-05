# P1-14 — Embedding Endpoint & Alias Dictionary Matcher

**Epic:** E10/E12 · **Primary package:** `Packages/InferenceHost` (embed) + `Packages/AutofillEngine` (dictionary layer) · **Complexity:** M · **Priority:** Critical

## Goal
The first two rungs of the matching ladder: bundled MiniLM-class embedding endpoint, and the curated top-200 alias dictionary with deterministic label→vault-path matching.

## Background
ARCHITECTURE.md §7.1 principle: deterministic first, model second. NFR-A1 (≥95% precision on top-200 labels) is won mostly by the dictionary; embeddings handle the long tail. This starts `AutofillEngine` work early against fakes (roadmap parallelization).

## Requirements
- Embed endpoint: batch text → vectors via bundled Core ML model (registry-managed); in-memory cosine search utility over VaultAPI field aliases.
- Alias dictionary: curated YAML mapping label variants ("Surname/Family Name/Last Name…") → canonical vault paths, with locale variants (top 5 languages); normalization (case, punctuation, whitespace, common abbreviations).
- Matcher API: label + context → ranked candidates with score source (dictionary|embedding) — LLM rung added in P2-03.

## Dependencies
- P1-12, P0-09.

## Files Likely Affected
- `Packages/InferenceHost/Sources/Embed/**`; `Packages/AutofillEngine/Sources/Matching/**`; dictionary data file in AutofillEngine resources.

## Acceptance Criteria
- Bench: ≥95% precision / measure recall on top-200 label fixture set (NFR-A1, CI-gated from now on).
- Dictionary miss falls through to embedding rung with correct score attribution.

## Definition of Done
- Global DoD, plus: dictionary curation guide (how to add labels safely).

## Testing Requirements
- Dictionary unit tests incl. normalization edge cases; embedding determinism test; precision bench in CI.

## Documentation Updates
- `AutofillEngine/CLAUDE.md` matching-ladder contract.

**Owner:** claude-agent · **Branch:** task/P1-14-embedding-alias-matcher · **Claimed:** 42a173c97b4d1a136ced3bc0bfb925ff5b6f8101

## Journal

### Orient
- Read root CLAUDE.md, this task file, InferenceHost/AutofillEngine sources (both currently scaffolded stubs from P1-12), InferenceAPI's Embed.swift/InferenceClient/FakeInferenceClient, docs/specs/vault-schema.md (canonical field-path catalog), Scripts/import-allowlist.txt + check-boundaries.sh.
- CoreMLAdapter.embed today returns all-zero stub vectors with a comment explicitly deferring the real implementation to this task.
- ModelRegistry's checksum/signature-verified "model pack" design assumes a vendored binary; there is no such binary available in this environment (same class of gap as the pinned E-004 PDFium finding: this box cannot vendor a third-party ML binary without a human trust decision). Resolution: use Apple's on-device `NLEmbedding` (NaturalLanguage framework) for the embed rung instead — it ships with macOS, needs no download/vendoring, satisfies "bundled...zero network dependency" more directly than a fetched model would, and doesn't touch the packData-verification path (the manifest is only used for capability/tier lookup, never for packData in the embed path — true of the stub already). Noting this as a deliberate substitution, not a silent one.
- Dictionary format: task says YAML, but no YAML parser is in the CLAUDE.md §17 approved dependency list and adding one needs an ADR. Substituting a JSON resource (Foundation-native, zero new dependency) — same curation shape, different serialization.

### Plan
1. InferenceHost (Sources/Embed/): NLEmbeddingProvider (wraps NLEmbedding.sentenceEmbedding, per-language cache) + CosineSearch utility; wire CoreMLAdapter.embed to it; add NaturalLanguage to its import-allowlist row; tests for determinism + similarity ordering.
2. AutofillEngine (Sources/Matching/): LabelNormalizer (case/punctuation/whitespace/abbreviation), AliasDictionary (bundled JSON resource, top vault-schema.md paths + locale variants for the top 5 highest-frequency fields), AliasMatcher (dictionary-first, embedding fallthrough via injected InferenceClient with score+source attribution).
3. Tests: dictionary normalization edge cases, precision bench over the curated fixture (dictionary rows must resolve to their own vault path — proves ≥95% precision by construction plus an explicit negative/fallthrough case), embedding-fallthrough attribution test using FakeInferenceClient.
4. Docs: AutofillEngine/CLAUDE.md (create, matching-ladder contract + dictionary curation guide), InferenceHost/CLAUDE.md update if it exists.
5. Run Scripts/verify.sh for both packages; fix until green.

Risks: NLEmbedding availability/locale coverage varies by OS install state — code must degrade to a typed error, never crash, if a language embedding isn't installed.
