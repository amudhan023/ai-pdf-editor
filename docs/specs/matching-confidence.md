# Matching-ladder confidence calibration (P2-03)

Owner: `Packages/AutofillEngine` (`Matching/Confidence.swift`, `MatchCandidate.confidence`). See `AutofillEngine/CLAUDE.md`'s "Matching ladder" section for the ladder itself; this doc covers only the confidence tier each rung reports.

## Why a tier, not a raw score

The review UI (CLAUDE.md §2 "AI proposes; the human disposes") needs a coarse signal to decide default behavior (auto-fill vs. flag for review vs. leave blank) without the reviewer having to interpret a raw cosine-similarity number. `MatchConfidence` is `.high`/`.medium`/`.low`; every `MatchCandidate` carries one, derived from `(score, source)` via `ConfidenceCalibration.calibrate`.

## Per-rung calibration

| Source | Confidence | Reasoning |
|---|---|---|
| `.dictionary` | always `.high` | Exact match on `LabelNormalizer.normalize`d text against a curated alias — deterministic, no uncertainty band needed. |
| `.embedding` | `score >= 0.85` -> `.high`; `score >= 0.5` -> `.medium`; else `.low` | Cosine similarity against the dictionary's known vault paths. Thresholds are **bench-tunable, not derived from a real accuracy bench** — no matcher-precision bench suite exists yet in `Scripts/bench.sh` (same class of gap `tasks/escalations/E-009`-style entries document elsewhere: the infrastructure to CI-gate this is separate follow-up scope, not blocking this task's ladder logic). Retune these two constants once one exists. |
| `.llm` | always `.high` | Only ever constructed for a *validated* constrained-choice pick (`SemanticMatcher` checks `chosenCandidateIndex` is in-range before building an `.llm` candidate — an unvalidated/free-form response never reaches this path). The LLM saw the field's full assembled context (label, tooltip, section headers, nearby text) to disambiguate between close embedding candidates, which is stronger evidence than the embedding score alone. |

## Degradation path (Acceptance Criterion 2)

When the LLM tiebreak rung is unusable — `InferenceClient.generate` throws (e.g. `InferenceError.capabilityUnavailable(.generate, .intel)` on a tier without the endpoint), times out (`SemanticMatcher`'s hard `Task.sleep` race, default 2s), or returns an untrustworthy response (`nil` or out-of-range `chosenCandidateIndex`) — `SemanticMatcher` returns the **untouched embedding-rung candidates**, confidence included. This is a "downgrade" only in the sense that it *doesn't* upgrade to the LLM rung's `.high`; the reported confidence is always the embedding rung's own honest calibration, never inflated because a tiebreak was attempted.

## Known limitation: the fake can't reach `.medium`/`.low` in tests

`InferenceAPI.FakeInferenceClient`'s `deterministicVector` is an 8-dimensional, strictly non-negative hash-based stand-in (no semantic meaning by design — see its doc comment). Non-negative low-dimensional vectors structurally bias cosine similarity upward: an exhaustive random search over 200k candidate label strings against this package's `aliases.json` found no case scoring below ~0.89 (well inside the `.high` band). This means `SemanticMatcherTests` can only exercise the `.high` embedding band end-to-end through the fake; `ConfidenceTests` covers the `.medium`/`.low` thresholds directly via `MatchCandidate` construction instead. A real embedding model (once `InferenceHost` has one behind `InferenceClient` — today it's `NLEmbedding`, see P1-14's Journal) is expected to produce genuine separation across the full range; if it doesn't in practice, retune the thresholds above against real bench data, not this doc's assumption.

## Known limitation: determinism

"Deterministic given same inputs (temperature 0 / seeded)" (P2-03 Requirement 4) is only as strong as the concrete `InferenceClient` behind the `InferenceAPI` protocol. `GenerateRequest` exposes `priority: InferencePriority` (`.interactive`/`.background`) but **no temperature or seed parameter** — `InferenceAPI` is a frozen seam (ADR required to change), so `SemanticMatcher` cannot request true determinism from the generate endpoint itself today. `SemanticMatcher`'s own logic is deterministic (same `MatchContext` + same `InferenceClient` responses -> same `MatchOutcome`, proven by `SemanticMatcherTests.test_sameContextAndClient_producesIdenticalOutcomeAcrossRepeatedCalls`); whether the *real* LLM adapter behind `InferenceClient` is itself deterministic (temperature 0, fixed seed) is that adapter's responsibility, out of this package's scope. Flagging here rather than silently assuming it's solved.
