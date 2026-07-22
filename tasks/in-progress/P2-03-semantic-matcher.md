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
