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
