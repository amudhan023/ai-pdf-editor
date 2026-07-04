# P0-11 — Agent Loop Auto-Continue After Merge

**Owner:** claude-code · **Branch:** task/P0-11-agent-loop-auto-continue · **Claimed:** 04fc2047887eade1dd47dd0277cf1b3507a6e34e

**Epic:** E1 · **Primary package:** none (process doc, root-adjacent companion doc) · **Complexity:** S · **Priority:** Medium

## Goal
The agent loop should automatically continue to the next task after a PR merges, instead of stopping and waiting for a human prompt between tasks.

## Background
`docs/AGENT_LOOP.md` Step 8 (COMPLETE) and Step 9 (IMPROVE, then loop) previously described merging and looping without specifying how an agent should wait for merge confirmation or when it's safe to treat that wait as "not a stop condition." This task makes that explicit: poll for merge/CI status on a ~5-minute cadence, sync `main`, then proceed to the next SELECT automatically. Human review/escalation requirements (CLAUDE.md §21, AGENT_LOOP.md §8/§9) are unchanged — this only removes an unnecessary pause between tasks that already cleared every gate.

## Requirements
- `docs/AGENT_LOOP.md` §1 intro states task-to-task continuation is the default behavior, not something requiring a human prompt.
- The mermaid diagram in §1 reflects a `Wait` state between PR-open and merge-complete, with explicit transitions for merged/CI-red/rejected outcomes.
- Step 8 (COMPLETE) is split into sub-steps: open/merge (8a), wait-and-verify-merge on a ~5 minute poll cadence (8b), sync `main` via fast-forward pull (8c), task-file housekeeping (8d).
- Step 9 states explicitly that returning to Step 0 is automatic.
- §8 Stop Conditions gets a clarifying note that the 8b wait is not condition 1 ("no unblocked tasks").
- No change to who is allowed to merge what — PRs requiring human review (`[INTEGRATION]`, security-touching, `*API`/`Schemas/`) still wait indefinitely for that review; this task does not grant agents new merge authority.

## Dependencies
- None.

## Files Likely Affected
- `docs/AGENT_LOOP.md`

## Acceptance Criteria
- `docs/AGENT_LOOP.md` reads as a coherent, self-consistent loop description with no contradictions between §1, Step 8/9, and §8 Stop Conditions.
- A future agent reading the doc cold would know: (a) it should not ask permission to start the next task after a merge, (b) how to poll for merge status and for how long, (c) what to do if CI goes red or the PR is rejected mid-wait.

## Definition of Done
- Global DoD (tasks/README.md), plus:
- Change is scoped to `docs/AGENT_LOOP.md` only — no drive-by edits to CLAUDE.md, ROADMAP.md, or other root docs.
- PR explicitly flags that this is a process-governance doc change and requests human review, per `docs/AGENT_LOOP.md`'s own rule that changes to itself are human-reviewed.

## Testing Requirements
- None (documentation-only change; no code path to test).

## Documentation Updates
- `docs/AGENT_LOOP.md` is the change itself.

## Journal
- Implemented earlier in this session, but merged in accidentally bundled with PR #1 (P0-01 repo scaffold). Cleanly reverted out of `main` via PR #5 (merged) so it could be redone as its own scoped task. This file/task/PR is that redo.
