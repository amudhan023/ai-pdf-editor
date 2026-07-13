# P0-16 — Wire Task `Complexity` into Supervisor Effort Selection

**Epic:** E1 · **Primary package:** none (process tooling — `claude_supervisor.py`) · **Complexity:** M · **Priority:** Medium

## Goal
`claude_supervisor.py` invokes every iteration with a flat `--effort medium`, regardless of the size of the task the agent ends up picking. Make the per-run effort level follow the task's own `Complexity: S/M/L` metadata instead of being constant, so small tasks don't pay for effort they don't need and large tasks aren't under-provisioned.

## Background
Task files already carry a `Complexity` field in their header (`## Complexity scale` in `tasks/README.md`: S ≈ ≤1 agent-day, M ≈ 1–3 days, L ≈ 3–5 days). `claude_supervisor.py`'s current loop is single-phase: one opaque `claude -p BOOTSTRAP_PROMPT` call both selects the task from `tasks/backlog/<phase>/` *and* does the work, so the supervisor process itself never learns which task was picked, or its Complexity, before or during the run — it only sees exit code and whether HEAD moved.

This came out of a review of the supervisor loop (2026-07-12) that also proposed several other changes (a `--max-turns` flag, inline "don't scan the repo" prompt text, model tiering by task type, shorter probe intervals). Those were evaluated and rejected/deferred as either already covered by `docs/AGENT_LOOP.md` §"Context discipline rules" and `docs/TOKEN_EFFICIENCY.md`, not supported by the installed `claude` CLI (no `--max-turns` flag exists), or not evidence-backed (probe-interval waste was checked against `.claude-supervisor/logs/supervisor.log` and found to be fast-fail, not costly). This task is the one concrete, real gap that survived that review.

## Requirements
- Restructure the supervisor's per-iteration flow so task selection is observable before the work-effort call is made — e.g. a lightweight pre-step (Claude call or deterministic script) that picks and moves the task file to `tasks/in-progress/`, parses its `Complexity` field, and only then invokes the work call with an effort level derived from it. Do not have the work-effort call itself re-decide which task to work — the point is to know Complexity *before* choosing effort, not after.
- Complexity → effort mapping is a simple, explicit table (e.g. S → `low`/`medium`, M → `medium`, L → `high`), not a heuristic; document the mapping directly in `claude_supervisor.py` as a small constant, not derived at runtime from other signals.
- Do not lower effort below `medium` for any task in a package under `Packages/*API/`, `Vault.xpc`, `DocEngine.xpc`, `Inference.xpc`, or `PolicyKit` regardless of stated Complexity — security/boundary-sensitive work keeps a quality floor irrespective of size (root `CLAUDE.md` §7/§8 outrank token-cost optimization).
- If the pre-step can't determine a task's Complexity (missing field, malformed header, or no task selected), fall back to the current flat `medium` — never fail the iteration or block the loop over this.
- Preserve all existing supervisor behavior this task doesn't touch: preflight checks, token-limit detection/probing, no-op/failure backoff and their thresholds, one-task-per-run contract.

## Dependencies
- None (P0-11 through P0-15, which established the loop and its retry/backoff policies, are already in `done/`).

## Files Likely Affected
- `claude_supervisor.py`
- `docs/AGENT_LOOP.md` (if the task-selection step changes observably — note it, don't restructure the doc beyond that delta)

## Acceptance Criteria
- Given two consecutive iterations that pick an S-complexity and an L-complexity task respectively, the logged/observable effort level passed to the work-effort `claude -p` call differs between them and matches the documented mapping.
- A task with no parseable `Complexity` field still runs (at `medium`), not a supervisor crash or stall.
- A task whose primary package is one of the always-medium-floor packages listed above never gets `low` effort even if marked Complexity S.
- Existing supervisor test coverage (if any) plus new coverage for the mapping function passes; no regression in token-limit/no-op/failure handling paths.

## Definition of Done
- Global DoD, plus: manual verification note in the PR showing at least one real supervisor run (or a scripted dry-run) demonstrating the effort level actually varies by task Complexity.

## Testing Requirements
- Unit tests for the Complexity → effort mapping function, including the missing-field fallback and the security-package floor override.
- No corpus/bench suite involvement (process tooling, not product code).

## Documentation Updates
- `claude_supervisor.py` inline comment documenting the mapping table's rationale (this is process code, not a product package, so no package `CLAUDE.md` applies).
