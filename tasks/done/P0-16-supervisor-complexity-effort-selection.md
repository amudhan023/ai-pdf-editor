# P0-16 — Wire Task `Complexity` into Supervisor Effort Selection

**Owner:** claude-agent · **Branch:** task/P0-16-supervisor-complexity-effort-selection · **Claimed:** c0cd0fedd92957322a32baab69feb7533bff778f

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

## Journal

### Orient
Read root `CLAUDE.md`, this task file, `tasks/README.md` (Complexity/Priority scales), and `claude_supervisor.py` in full. No package `CLAUDE.md` applies (process tooling, not a product package). Surveyed `**Primary package:**` field formats across all task files to confirm real naming: `Packages/*API` packages exist (VaultAPI, PDFEngineAPI, InferenceAPI), `Packages/PolicyKit` exists, and the conceptual `Vault.xpc`/`DocEngine.xpc`/`Inference.xpc` process names from CLAUDE.md §3.2 map to the real `Services/VaultService`, `Services/DocEngineService`, `Services/InferenceService` targets per `docs/REPO_STRUCTURE.md` (Services/ comment: "the three .xpc bundle targets"). Confirmed `pytest` is on PATH; no existing Python test scaffold in the repo, so tests will be stdlib `unittest`-based (runnable via `python3 -m unittest`, pytest-discoverable too).

### Plan
1. Split the current single `claude -p` call into two: a narrow **SELECT_PROMPT** call (Step 0 of AGENT_LOOP.md only — pick, claim, commit, stop) and a **WORK_PROMPT** call (Steps 1–9, continuing the already-claimed task, no re-selection), so the supervisor can observe which task got picked before choosing effort. Both remain within `run_claude`'s existing subprocess/timeout/token-limit-detection machinery (reused, not duplicated).
2. After the SELECT call, diff `tasks/in-progress/` before/after to find the newly claimed file (HEAD-move already distinguishes real selection from the "no valid task" no-op path, matching existing `record_outcome` logic).
3. Parse `**Complexity:**` and `**Primary package:**` from that file with a small regex-based helper; map via an explicit `COMPLEXITY_EFFORT` table (S→low, M→medium, L→high), with a security-package floor (`Packages/*API`, `PolicyKit`, `Services/{Vault,DocEngine,Inference}Service`, literal `.xpc`) that never lets effort go below `medium`. Missing/malformed Complexity, or an ambiguous/absent selection, falls back to flat `medium` — never blocks the loop.
4. Feed the resolved effort into the WORK_PROMPT call's `--effort` flag. Log the resolved task id + complexity + effort for observability (serves acceptance criterion 1).
5. Unit tests (`test_claude_supervisor.py`, stdlib `unittest`) for the mapping function: S/M/L happy path, missing field fallback, malformed field fallback, security-floor override (each floor pattern), non-floor package at Complexity S stays `low`.
6. No corpus/bench involvement (process tooling). `Scripts/verify.sh` doesn't apply to a package-less change — acceptance criteria call for a manual verification note (real or scripted dry run) instead; will do a scripted dry run against a synthetic backlog task and paste output into the PR.

Risks: replicating full Step 0 priority/tie-break logic in Python would drift from AGENT_LOOP.md's algorithm — avoided by keeping selection inside a real Claude call (explicitly allowed by the task) rather than reimplementing it deterministically. Package-floor pattern list is my inference from REPO_STRUCTURE.md's Services/ mapping since no task file literally spells "Vault.xpc" — noting this in the PR rather than silently guessing further.

### Implement
Split `BOOTSTRAP_PROMPT` into `SELECT_PROMPT` (Step 0 only, its own tight `SELECT_RUN_TIMEOUT_SECONDS=180`) and `WORK_PROMPT` (Steps 1-9, instructed not to re-select). Added `COMPLEXITY_EFFORT`/`DEFAULT_EFFORT`/`SECURITY_FLOOR_PACKAGE_PATTERNS` constants, `parse_task_header`/`is_security_floor_package`/`effort_for_task` (the mapping function, pure and directly testable) and `resolve_effort_for_claim` (diffs `tasks/in-progress/` before/after SELECT to find the claim, reads it, calls the mapping function). Generalized `run_claude`/`wait_for_reset` to take `(prompt, effort, timeout)` instead of hardcoding them, and added `run_with_token_handling` to dedupe the run+log+token-probe sequence now used twice per iteration (SELECT then WORK) instead of once. Rewrote `main()`'s loop body around the two-call sequence; preserved `record_outcome`'s no-op/failure/success classification and `state` counters unchanged.

### Verify
No `Scripts/verify.sh <Package>` applies (Primary package is "none", same as prior process-tooling tasks P0-12/P0-13 in `done/`). Instead: `python3 -m unittest test_claude_supervisor -v` — 23/23 pass, covering the mapping function's S/M/L happy path, missing/malformed-Complexity fallback, and the security-floor override for each pattern (`Packages/*API`, `PolicyKit`, literal `.xpc`, all three `Services/*Service` targets), plus a check that the floor never *lowers* an already-higher effort. `python3 -c "import ast; ast.parse(...)"` confirms the full file still parses. Two scripted dry-runs (pasted below) exercise `resolve_effort_for_claim` end-to-end: one against this task's own real claim in `tasks/in-progress/` (Complexity M → effort `medium`), one against synthetic S- and L-complexity task files in a temp `tasks/in-progress/` proving consecutive iterations resolve to distinct, correctly-mapped efforts (`low` then `high`) — this is acceptance criterion 1 directly.

```
$ python3 -m unittest test_claude_supervisor -v
...
Ran 23 tests in 0.001s
OK

$ python3 - <<'PY'
# resolve_effort_for_claim against this task's own real in-progress/ claim
Resolved: task=P0-16-supervisor-complexity-effort-selection.md effort=medium
PY

$ python3 - <<'PY'
# synthetic S then L task claimed in two consecutive iterations
Iteration 1: P9-01-small-task.md -> effort=low
Iteration 2: P9-02-large-task.md -> effort=high
PASS: consecutive S/L iterations resolve to distinct, correctly-mapped efforts
PY
```

### Harden
Re-read the full diff as a hostile reviewer. No dead code, debug scaffolding, or narrating comments added. `has_in_progress_conflict` was already unused before this change (pre-existing, out of scope — not touched). Verified `--effort low` is accepted by the installed `claude` CLI (`claude --help` lists `low, medium, high, xhigh, max`). Confirmed the token-limit-hit path still behaves correctly for either call (SELECT or WORK) via the generalized `wait_for_reset(state, prompt, effort, timeout)` — probes re-run the exact call that hit the limit. Confirmed `git status` after all dry-runs shows no stray writes into the working tree outside `.claude-supervisor/` (which is excluded from the supervisor's own cleanliness preflight by design).

**Security/privacy self-audit:** this code touches no document content, vault content, or PII — it only reads/writes task-file headers (public repo metadata: Complexity, Primary package) and process bookkeeping (`.claude-supervisor/state.json`, run logs). No new logging of secrets; log lines emit task IDs, complexity letters, and effort strings only, consistent with the existing supervisor.log conventions (§16 does not apply, this isn't product code, but the same discipline holds).

**Architecture judgment (G4):** No new type duplicates an API-package concept (this is standalone process tooling, no product package boundary applies). No logic placed in a layer that will need moving — `effort_for_task` is the one seam a future change would touch, and it's already isolated as a pure function. ARCHITECTURE.md needs no edit — this change is below its scope (agent-loop tooling, not product architecture).

### Gate
G1: no Swift/package build applies; new Python tests pass; diff scope is `claude_supervisor.py` + `test_claude_supervisor.py`, matching the task's `Files Likely Affected` (the second doc bullet — an AGENT_LOOP.md delta — turned out unnecessary: the task-selection *contract* AGENT_LOOP.md documents didn't change, only the supervisor's internal call structure, so no doc edit was needed there). G2: security self-audit above, no red-line grep hits (no network, no `print(`, no `SecureBytes`/vault types involved, no `/tmp`, no JS eval - N/A domain). G3: N/A, not a benched path. G4: judgment notes above, no frozen seam touched.
