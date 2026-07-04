# E-003 — Branch protection unavailable on GitHub Free (private repo)

**Raised by:** P0-02 · **Severity:** DoD gap, not a code defect — CI itself works and is unaffected

## Evidence
- `gh api repos/amudhan023/ai-pdf-editor/branches/main/protection` (both GET and the intended PUT to configure required status checks) returns:
  `403 {"message":"Upgrade to GitHub Pro or make this repository public to enable this feature."}`
- This is a GitHub plan restriction, not a permissions or scope issue: branch protection rules (required status checks, required reviews, etc.) are only available on private repositories with GitHub Pro/Team/Enterprise, or on any public repository, per GitHub's pricing tiers.
- `.github/workflows/ci.yml` (P0-02) itself is unaffected and works today: every PR triggers the `ci-status` check, visible on the PR, green/red as expected. What's missing is GitHub *technically blocking the merge button* until it's green — right now that's enforced by discipline (checking the PR checks tab before merging) rather than the platform.

## Decision needed (human — billing)
Option A (recommended if this repo stays private and the team grows past one person): upgrade to GitHub Pro ($4/mo as of this writing) at github.com/settings/billing, then configure:
  `gh api -X PUT repos/amudhan023/ai-pdf-editor/branches/main/protection -f required_status_checks[strict]=true -f 'required_status_checks[checks][][context]=ci-status' -F enforce_admins=false -F required_pull_request_reviews=null -F restrictions=null`
  (`enforce_admins=false` matches the earlier decision: CI status required, no mandatory review count, admin/owner can still self-merge.)
Option B: make the repo public — unlocks the same feature for free, but exposes proprietary source (against this product's whole premise per CLAUDE.md §1).
Option C (current default): skip the hard gate. CI still runs and reports status on every PR; merge discipline is manual (check the Checks tab is green before merging) rather than platform-enforced.

## After repair
If Option A or B is chosen: run the `gh api -X PUT ...` command above (or re-derive it — GitHub's API for this may have moved on by the time this is revisited), confirm `gh api repos/amudhan023/ai-pdf-editor/branches/main/protection` returns the configured rule, then check the corresponding line in `tasks/in-progress/P0-02-ci-pipeline.md`'s Definition of Done.
