# E-012 — Git LFS bandwidth budget exceeded (blocks `ci-status` on every open PR)

**Raised by:** chore/ci-lfs-bandwidth-cache (#89) · **Severity:** blocks merge of every currently-open PR (#85, #86, #87, #88, #89) — repo/account-wide, not specific to any one diff · **Status: OPEN**

## Evidence

- Every job in `ci.yml` that runs `actions/checkout` with `lfs: true` (or, after #89, an explicit `git lfs pull`) fails at that step with:
  > `batch response: This repository exceeded its LFS budget. The account responsible for the budget should increase it to restore access.`
  > `Failed to fetch some objects from 'https://github.com/amudhan023/ai-pdf-editor.git/info/lfs'`
- Reproduced identically on PR #85 (`task/P1-06-page-management`, run `29888180908`, 2026-07-22) — i.e. this predates PR #89 by a day, so it is not something #89 introduced.
- Still reproduces on PR #89 itself (run `29980327966`, 2026-07-23) even though #89's whole purpose was switching from `checkout`'s `lfs: true` to an `actions/cache`-keyed `git lfs pull`. The cache-based approach is a correct fix for *future* bandwidth usage (only the first job per LFS content-key pays the network cost instead of every job on every run), but it cannot help *this* failure: the account's monthly LFS bandwidth quota is already at zero, so even the one required network fetch (whichever job is unlucky enough to be first for a given cache key) is rejected.
- Confirmed via `gh pr checks` that #85, #86, #87, #88, #89 all fail with this exact signature on `app`, `repo-checks`, `services`, and (where applicable) `verify`/`integration-tests` — every job that touches `Fixtures/**` or `ThirdParty/pdfium/prebuilt/**` LFS content.
- `gh api /settings/billing/packages` and `/settings/billing/actions` both 404 for this token/account (personal account billing isn't exposed via this API surface) — usage/quota state can only be checked at github.com/settings/billing in a browser, which is outside this agent's tool access.

## Conclusion

Not a code defect and not fixable by any further workflow-file diff: LFS bandwidth quota is an account-level billing meter, separate from LFS storage (well under 1GB) and separate from Actions minutes (see the already-resolved `E-006`). No caching strategy changes what has already been consumed this billing cycle. This blocks the standing merge authorization in root `CLAUDE.md` §21 for *every* open PR right now, not just #89's: the rule is "never merge on red," and CI cannot currently produce anything but red on the LFS-touching jobs, through no fault of the code under review.

## Decision needed (human — billing)

At `github.com/settings/billing` (Git LFS Data section): either wait for the next monthly bandwidth reset, or purchase an additional Git LFS data pack to restore access immediately. This is explicitly the class of thing `docs/AGENT_LOOP.md` §9's escalation table reserves for a human: "Anything requiring spending money, external accounts, publishing, or real-world data acquisition."

## Interim decision (made now, so this isn't silently merged around)

PRs #85, #86, #87, #88, #89 all stay open, unmerged, with `ci-status` red, per the absolute rule "never merge with failing or skipped gates to unblock" and "never merge on red under any circumstance." No further fix-and-recheck attempts against any of their code are useful — the failure is not in the code. Work continues on new tasks whose branches don't yet need a real CI run to make progress; each PR still needs a green `ci-status` before it can merge, so none should be force-merged or have gates skipped.

## After repair

Once the LFS budget is restored: re-run each PR's latest CI (`gh run rerun <id>` on #85/#86/#87/#88/#89, or push a small change) to get a real `verify`/`repo-checks`/`app`/`services` execution (not another instant LFS-fetch failure), confirm `ci-status` goes green, then merge each per the standing autonomous-merge authorization (ordinary, non-blocked-by-anything-else changes only — check each PR's own review checklist first).
