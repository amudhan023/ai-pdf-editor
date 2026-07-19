# E-006 — GitHub Actions is entirely blocked by an account billing issue (blocks all CI, all PRs)

**Raised by:** P0-08 · **Severity:** blocks merge of PR #18 (and, structurally, every other open/future PR — this is repo/account-wide, not specific to this diff) · **Status: RESOLVED (2026-07-04) — see Update below**

## Update — RESOLVED (2026-07-04)

Billing was fixed: PR #18 merged on 2026-07-04 (`bb7d42c`) after `ci-status`
ran a real `verify`/`repo-checks` execution and went green — not another
instant failure. Every PR merged since (through #74/#75, most recently
verified 2026-07-19) has run full CI normally. This escalation stays open
only as history; do not re-file a new escalation for the same underlying
condition without first checking `gh pr checks <PR>` for the instant-failure
signature described in Evidence below — that's the tell it has recurred.

## Evidence

- PR #18 (`task/P0-08-fixtures-bench-harness`) triggered `ci.yml` normally on
  open. Every job failed within 2-4 seconds — far too fast to be a real
  build/test/lint failure (compare: a real `verify` job takes minutes).
- `gh run view 28714664419` shows the actual cause via GitHub's own annotations,
  identical on `detect-changes`, `repo-checks`, and `ci-status`:
  > "The job was not started because recent account payments have failed or
  > your spending limit needs to be increased. Please check the 'Billing &
  > plans' section in your settings"
- Re-ran the workflow once (`gh run rerun 28714664419`) to rule out a
  transient blip: identical failure, identical annotation, same ~2-4s
  non-start. This is not flaky infrastructure — it is GitHub refusing to
  schedule any Actions job for this account at all.
- This is distinct from `tasks/escalations/E-003-branch-protection-needs-paid-plan.md`
  (which is about a GitHub *feature* — branch protection — being gated behind
  a paid plan tier, while CI itself was confirmed working). This is CI itself
  not running at all, for any job, on any workflow, repo-wide.

## Conclusion

Not a code defect and not fixable by any diff to this PR or any other: no
number of pushes, reverts, or workflow-file changes changes GitHub's decision
to refuse scheduling Actions jobs for an account with a payment/spending-limit
problem. This blocks the standing merge authorization in root CLAUDE.md SS21 /
`docs/AGENT_LOOP.md` Step 8a for *every* ordinary PR, not just this task's:
the rule is "never merge on red," and CI cannot currently produce anything
but red, through no fault of the code under review.

## Decision needed (human — billing)

Check github.com/settings/billing (or the organization's billing page if
`amudhan023` is later moved under one) for the specific failed-payment or
spending-limit condition GitHub's annotation refers to, and resolve it
(update payment method, or raise the Actions spending limit). This is
explicitly the class of thing `docs/AGENT_LOOP.md` SS9's escalation table
reserves for a human: "Anything requiring spending money, external accounts,
publishing, or real-world data acquisition."

## Interim decision (made now, so this isn't silently merged around)

PR #18 stays open, unmerged, with `ci-status` red, per the absolute rule
"never merge with failing or skipped gates to unblock" (root CLAUDE.md SS21)
and "never merge on red under any circumstance." No further fix-and-recheck
attempts against this PR's code are useful — the failure is not in the code.
This escalation is the record of why the PR is stalled; re-check `gh pr
checks 18` after the billing issue is resolved and re-run the workflow
(`gh run rerun <id>`) rather than pushing a no-op commit to retrigger it.

## After repair

Once billing is resolved: re-run PR #18's CI (`gh run rerun` on the latest
run, or push any small change), confirm `ci-status` goes green through an
actual `verify`/`repo-checks` execution (not another instant failure), then
merge per the standing autonomous-merge authorization (this PR is an
ordinary, non-`[INTEGRATION]`, non-security, non-API/Schema change).
