**Owner:** claude-code · **Branch:** task/P0-14-branch-protection-live · **Claimed:** 0379fe7

# P0-14 — Branch Protection Now Platform-Enforced (E-003 Resolved)

**Epic:** E1 · **Primary package:** none (process doc) · **Complexity:** S · **Priority:** Medium

## Goal
Reflect reality: `main` now has platform-enforced branch protection (required `ci-status` check), so the docs should stop saying the agent's own CI check is the only gate.

## Background
E-003 (branch protection unavailable on GitHub Free for private repos) was resolved when the human operator made the repo public to fix an unrelated GitHub Actions billing block, which incidentally also unlocked branch protection. `required_status_checks: {strict: true, checks: [{context: "ci-status"}]}`, `enforce_admins: false` (owner can still self-merge) is now live on `main`.

## Requirements
- `tasks/escalations/E-003-branch-protection-needs-paid-plan.md`: mark genuinely resolved (not just resolved-by-decision-to-skip), record the actual configuration applied and when/why (repo went public for billing, not specifically for this).
- `CLAUDE.md` §21: update the "branch protection is not currently platform-enforced" language — it now is. Keep the guidance that the agent should still treat CI as authoritative (checking `ci-status` before assuming mergeable is still good practice / matches how any agent would behave), but stop implying GitHub isn't backing it up.
- `docs/AGENT_LOOP.md` Step 8a: same update — the "no platform-enforced branch protection" framing that justified "the agent's own check of ci-status is the gate" needs to reflect that GitHub now also enforces this directly.
- No change to the 5-attempt CI-fix-and-retry-merge cap, the review-required carve-outs (`[INTEGRATION]`/security/API-schema/CLAUDE.md+AGENT_LOOP.md), or the unconditional backlog auto-continuation policy — those are unaffected by who technically enforces the CI-green requirement.

## Dependencies
- None (process doc only).

## Files Likely Affected
- `tasks/escalations/E-003-branch-protection-needs-paid-plan.md`, `CLAUDE.md`, `docs/AGENT_LOOP.md`

## Acceptance Criteria
- Docs accurately describe that `main` has a real, GitHub-enforced required status check, not just an agent-side discipline.
- `gh api repos/amudhan023/ai-pdf-editor/branches/main/protection` confirms the live configuration (already verified: `contexts: ["ci-status"], enforce_admins: false, strict: true`).

## Definition of Done
- Global DoD, plus: this PR requests human review (touches `CLAUDE.md`/`AGENT_LOOP.md`, per §10's own rule).

## Testing Requirements
- None (documentation-only).

## Documentation Updates
- This task's changes are the documentation.

---
## Journal

**Done:** configured branch protection live via `gh api -X PUT .../branches/main/protection` (JSON body, since `-f`/`-F` flags don't coerce nested booleans correctly for this endpoint — used `--input` with a real JSON file instead). Verified via a follow-up GET. Updating E-003 + CLAUDE.md + AGENT_LOOP.md in this same PR to match reality.

**Not a retroactive claim:** the repo went public to fix an unrelated GitHub Actions billing block (E-006) — branch protection becoming available was a side effect the human operator then asked to be enabled, not the original reason for going public. Recorded accurately in E-003's resolution note rather than implying this was planned from the start.
