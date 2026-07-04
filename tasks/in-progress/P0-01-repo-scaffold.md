**Owner:** claude-code (session 0990) · **Branch:** task/P0-01-repo-scaffold · **Claimed:** 6fee6ab
# P0-01 — Repository Scaffold & Context System

**Epic:** E1 · **Primary package:** repo root `[INTEGRATION]` · **Complexity:** M · **Priority:** Critical

## Goal
Stand up the full repository skeleton from REPO_STRUCTURE.md so every subsequent task has its workspace, context file, and verification entry point.

## Background
The layout in docs/REPO_STRUCTURE.md §2 is the contract for all parallel work: one SPM package per module, per-package `CLAUDE.md`, `Scripts/verify.sh`. This task creates the empty-but-building shell.

## Requirements
- Create directory tree per REPO_STRUCTURE.md §2: `App/`, all `Packages/*` with `Sources/`, `Tests/`, `CLAUDE.md` stubs, `Services/`, `Schemas/`, `Scripts/`, `Fixtures/` (LFS configured), `tasks/` (already present), `docs/adr/`.
- Root `CLAUDE.md` per REPO_STRUCTURE.md §4; each package `CLAUDE.md` states purpose + forbidden imports (≤60 lines).
- `Scripts/bootstrap.sh` and `Scripts/verify.sh <Package>` (build + test + import-boundary lint via SwiftLint custom rules).
- Every package compiles empty; `verify.sh` passes for all packages.

## Dependencies
- None (first task).

## Files Likely Affected
- Entire tree (creation only); no product logic.

## Acceptance Criteria
- Fresh clone → `Scripts/bootstrap.sh` → `Scripts/verify.sh PolicyKit` (and every other package) exits 0.
- Boundary lint fails a deliberate illegal import (demonstrated in a test).

## Definition of Done
- Global DoD, plus: ADR-000 recording repo conventions committed.

## Testing Requirements
- CI-executable smoke: script that runs `verify.sh` across all packages.
- Negative test for boundary lint.

## Documentation Updates
- README.md quickstart; docs/adr/ADR-000-repo-conventions.md.
