**Owner:** claude-code · **Branch:** task/P0-02-ci-pipeline · **Claimed:** 0ee0540

# P0-02 — CI Pipeline

**Epic:** E1 · **Primary package:** `.github/workflows` · **Complexity:** M · **Priority:** Critical

## Goal
Per-package CI matrix so every PR is verified with exactly the same command agents run locally.

## Background
REPO_STRUCTURE.md §1 principle 4: "works for the agent" must equal "works in CI". CI calls `Scripts/verify.sh` per changed package, plus repo-wide checks.

## Requirements
- `ci.yml`: detect changed packages from diff → matrix of `verify.sh <Package>` jobs; full matrix on main.
- Repo-wide jobs: SwiftLint, secret scan + PII-pattern scan over `Fixtures/`, codegen drift check (`Scripts/codegen.sh --check`).
- macOS runner with pinned Xcode; PR status required before merge.
- `bench.yml` stub (manual trigger) reserved for P0-08 harness.

## Dependencies
- P0-01.

## Files Likely Affected
- `.github/workflows/ci.yml`, `bench.yml`; `Scripts/verify.sh` (flags only).

## Acceptance Criteria
- PR touching one package runs only that package's job + repo-wide checks; PR touching `Packages/*API/` triggers full matrix.
- A planted fake SSN pattern in `Fixtures/` fails CI.

## Definition of Done
- Global DoD, plus: branch protection configured on main.

## Testing Requirements
- Demonstration PRs exercising: single-package path, API-change full-matrix path, PII-scan failure.

## Documentation Updates
- Root `CLAUDE.md` CI section; tasks/README.md if workflow details change.

---
## Journal

**Dependency note:** P0-01 is not yet in `done/` — its test-execution acceptance criterion is blocked on E-002 (no full Xcode on the local dev machine). Proceeding with P0-02 anyway, at the human operator's explicit direction, because CI itself does not share that blocker: GitHub-hosted `macos-15` runners ship a full Xcode install, so `swift test` (and therefore real per-package verification) works in CI today even though it can't run locally yet. The `verify` job's "Confirm full Xcode toolchain" step asserts this explicitly rather than assuming it silently.

**Done:**
- `.github/workflows/ci.yml` — `detect-changes` (diff-based changed-package list; full matrix on push to `main` or any `Packages/*API/`/`Schemas/` touch) → `verify` (matrix of `Scripts/verify.sh <Package>`, `macos-15`, fail-fast disabled) → `repo-checks` (SwiftLint, `Scripts/scan-fixtures-pii.sh`, `Scripts/codegen.sh --check`) → `ci-status` (single aggregator job, the one required status check — matrix job names are dynamic so branch protection can't target them individually).
- `.github/workflows/bench.yml` — `workflow_dispatch`-only stub, reserved for P0-08, matching how `Scripts/codegen.sh` was already stubbed for this task.
- `Scripts/scan-fixtures-pii.sh` — POSIX-ERE (no `\b`, no PCRE syntax, so BSD grep and GNU grep agree) pattern scan for SSN/credit-card/AWS-key/private-key shapes over `Fixtures/`; `--self-test` flag mirrors `check-boundaries.sh`'s convention (plants a fake SSN, asserts detection, cleans up). Ran locally: clean scan on current (empty) `Fixtures/`, self-test passes.
- `.swiftlint.yml` — file/type/function length caps matching CLAUDE.md §4's ~400-line soft cap, `force_try` as error, `force_unwrapping` as warning (noted in-file: SwiftLint has no clean per-directory exemption for Tests/ vs Sources/, so the "no force-unwraps outside tests" distinction stays a review-time rule for now, not a hard CI gate — flagged as a possible follow-up, not silently dropped).
- `CLAUDE.md` Quick Reference Card updated with the CI entry point and the PII-scan script.

**Verified live (PR #7):**
- First Actions run caught a real bug: `set -euo pipefail` + `grep -oE` finding zero matches (this PR touches no `Packages/` paths) made `detect-changes` fail even though the intended output — an empty package list, meaning "nothing to verify" — was correct. Fixed by isolating that grep stage with `|| true` so its exit code can't propagate through the pipe via `pipefail`; re-ran, confirmed green. Caught by watching the actual run, not assumed from reading the YAML.
- Second run: `detect-changes` (pass, correctly emitted `packages=[]`), `verify` (skipped — correct, zero packages in the matrix), `repo-checks` (pass — SwiftLint, PII scan, codegen check all green), `ci-status` (pass). This exercises the single-package/zero-package path live. The `*API`-touch full-matrix path and a live PII-scan-failure demo are still only proven locally (self-test) / by design, not yet by a dedicated throwaway PR — leaving that as a follow-up rather than blocking this task on manufacturing a demo PR.

**Blocked: branch protection (DoD item unmet, not a code defect).** `gh api` confirms GitHub Free does not allow branch protection rules on private repos (403: "Upgrade to GitHub Pro or make this repository public"). Filed as `tasks/escalations/E-003-branch-protection-needs-paid-plan.md`. Human operator's explicit decision: skip the hard merge-blocking gate for now rather than upgrade the plan or make the repo public. CI itself (the actual verification work) is fully live and unaffected — what's missing is GitHub *technically* blocking the merge button, which is now a manual-discipline step (check the PR's Checks tab before merging) instead of a platform guarantee.

**Status:** leaving this task in `in-progress/`, not `done/` — the DoD explicitly lists "branch protection configured on main" and that's genuinely not done, for a documented external reason. Revisit if/when E-003 is resolved (Pro upgrade or going public); until then this is a known, accepted gap, not a silently dropped one.
