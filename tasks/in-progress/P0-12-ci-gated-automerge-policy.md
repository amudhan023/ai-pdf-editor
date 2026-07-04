# P0-12 — CI-Gated Auto-Merge Policy

**Owner:** claude-code · **Branch:** task/P0-12-ci-gated-automerge-policy · **Claimed:** 0ee05405262342b9ea1849a11e9f143b42e7ed92

**Epic:** E1 · **Primary package:** none (process doc, root-adjacent companion doc) · **Complexity:** S · **Priority:** Medium

## Goal
Make "merge automatically once CI is green, never merge if it's red — fix and retry instead" the explicit, standing policy for ordinary PRs, since this repo has no platform-enforced branch protection to fall back on.

## Background
P0-02 wired up `.github/workflows/ci.yml` (the `ci-status` aggregator check), but `gh api` confirmed GitHub Free doesn't allow branch protection rules on private repos (`tasks/escalations/E-003-branch-protection-needs-paid-plan.md`). That means nothing on GitHub's side stops a merge before CI finishes — the agent itself has to check `ci-status` and treat it as the gate. The human operator explicitly directed: auto-merge on green, never on red, and when red, diagnose and fix rather than retry blindly or give up.

## Requirements
- CLAUDE.md §21 states plainly that branch protection is not currently platform-enforced (link E-003), and that for ordinary PRs (not `[INTEGRATION]`/security-touching/`*API`/`Schemas/`), the agent merges autonomously once `ci-status` is green — this is standing authorization, not a per-PR ask.
- `docs/AGENT_LOOP.md` Step 8 restructured so 8a explicitly: polls CI status, merges immediately if green and the PR isn't in a human-review category, and — if CI is red — returns to Step 4/6 to diagnose and fix (counts toward the 3-strike rule), then re-enters the poll. It never merges on red, and never merges an `[INTEGRATION]`/security/API-schema PR without requesting review first regardless of CI status.
- Step 8b is narrowed to specifically the human-review wait (only for the PRs that need one) rather than describing all merge waiting.
- No change to what counts as a human-review-required PR (CLAUDE.md §21's existing three categories), and no change to the E-003 decision itself (still deferred, per the human operator).

## Dependencies
- P0-02 (CI pipeline must exist for there to be a status to gate on).

## Files Likely Affected
- `CLAUDE.md` (§21)
- `docs/AGENT_LOOP.md` (Step 8, and the §8 Stop Conditions note that references it)

## Acceptance Criteria
- Reading CLAUDE.md §21 and AGENT_LOOP.md Step 8 together gives an unambiguous answer to "should I merge this PR right now?" for any combination of (CI green/red) × (ordinary/review-required PR), with no reliance on GitHub enforcing anything.
- The docs are honest about the current gap (no platform-enforced protection) rather than implying a technical guarantee that doesn't exist.

## Definition of Done
- Global DoD (tasks/README.md), plus:
- This PR itself is flagged for human review in its description, per `docs/AGENT_LOOP.md`'s own rule that changes to itself are human-reviewed — not auto-merged even though its content says future ordinary PRs should be.

## Testing Requirements
- None (documentation-only; no code path to test).

## Documentation Updates
- CLAUDE.md §21, docs/AGENT_LOOP.md Step 8 — this task's changes are the documentation.
