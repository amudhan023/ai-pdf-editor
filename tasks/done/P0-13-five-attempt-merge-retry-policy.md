**Owner:** claude-code · **Branch:** task/P0-13-five-attempt-merge-retry-policy · **Claimed:** main tip at task start

# P0-13 — Five-Attempt CI-Fix-and-Retry-Merge Policy, Full Backlog Auto-Continuation

**Epic:** E1 · **Primary package:** none (process doc) · **Complexity:** S · **Priority:** Medium

## Goal
Make explicit that the agent never waits for human approval between backlog tasks, and give the "PR is open, CI is red" loop a concrete, bounded retry cap (5 attempts) distinct from Step 4's pre-PR 3-strike local-verify rule.

## Background
Human operator directive: work the backlog autonomously, task after task, with no approval checkpoint in between. When a PR's CI fails, diagnose and fix, then retry the merge — up to 5 times for that PR. If still red after 5, stop and wait for human review rather than continuing to retry or moving on. This is a distinct, tighter-scoped counter than Step 4's "3 strikes" (which governs the local build/test fix loop *before* a PR exists at all) — Step 8a's counter is specifically about the open-PR CI-red-to-green retry cycle.

Also: `tasks/escalations/E-003-branch-protection-needs-paid-plan.md` is resolved by explicit human decision (Option C: skip the hard gate) — not to be re-raised. P0-02 closes with that noted, unblocking P0-05/P0-08.

## Requirements
- `docs/AGENT_LOOP.md` §1 states plainly: task-to-task continuation never pauses for approval; the only pauses are §8 Stop Conditions, §9 Escalation categories, and Step 8a's own review-required carve-out (`[INTEGRATION]`/security/API-schema/self-referential-doc PRs).
- Step 8a's red-CI bullet gets a concrete 5-attempt cap: fix → push → re-check, up to 5 times for a given PR. 5th attempt still red → stop, leave the PR open, Journal what was tried, wait for human review. Does not retry a 6th time, does not move to another task while this one sits unresolved.
- Existing carve-outs (§21's three categories + AGENT_LOOP's fourth for CLAUDE.md/AGENT_LOOP.md changes) are unchanged — this task does not touch who needs review, only how long the agent may keep trying before asking for help on an ordinary PR.
- E-003 marked resolved-by-decision in its own file (not re-litigated).

## Dependencies
- P0-12 (the policy this refines already exists).

## Files Likely Affected
- `docs/AGENT_LOOP.md` (§1, Step 8a, §8 note)
- `tasks/escalations/E-003-branch-protection-needs-paid-plan.md` (status update)
- `tasks/in-progress/P0-02-ci-pipeline.md` → `done/` (separate commit/PR, not bundled here)

## Acceptance Criteria
- Reading AGENT_LOOP.md Step 8a alone answers "how many times do I retry a failing CI check before I stop and ask for help" with a specific number, not "keep trying" or "use judgment."
- No ambiguity about whether task-to-task continuation requires a human checkpoint (it doesn't, except the named exceptions).

## Definition of Done
- Global DoD, plus: this PR itself requests human review (it edits `docs/AGENT_LOOP.md`, which per its own §10 rule always needs review).

## Testing Requirements
- None (documentation-only).

## Documentation Updates
- `docs/AGENT_LOOP.md`, `tasks/escalations/E-003-...md` — this task's changes are the documentation.
