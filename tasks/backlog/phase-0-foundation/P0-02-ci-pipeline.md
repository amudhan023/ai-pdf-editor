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
