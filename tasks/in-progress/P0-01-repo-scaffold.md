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

---
## Journal

**Done:**
- git repo initialized on `main`; task claimed per AGENT_LOOP §1 step 0; branch `task/P0-01-repo-scaffold`.
- 17 SPM packages scaffolded under `Packages/` (Package.swift, placeholder source, smoke test, CLAUDE.md ≤60 lines, README) with path dependencies matching ARCHITECTURE §3.1.
- `Scripts/`: `verify.sh` (build+test+boundary lint, exit-code strict, output-on-failure-only), `check-boundaries.sh` (portable shell allowlist checker + `--self-test`), `bootstrap.sh` (prereq checks incl. CLT warning), `codegen.sh` stub (interface stable for P0-02 CI).
- `Scripts/import-allowlist.txt` — machine-readable boundary source of truth.
- `App/`, `Services/{DocEngine,Inference,Vault}Service/`, `Schemas/` (both yml stubs), `ThirdParty/pdfium/`, `Fixtures/{pdf-corpus,forms,documents}/` (+ `.gitattributes` LFS rules), `docs/adr/ADR-000-repo-conventions.md`, root `README.md`.

**Deviation from task text (recorded in ADR-000):** boundary lint is a portable shell checker, not SwiftLint custom rules — SwiftLint is not installed and the shell checker has zero tool dependencies; SwiftLint can layer on in P0-02.

**Acceptance criteria status:**
- Boundary lint fails a deliberate illegal import: ✅ (`check-boundaries.sh --self-test` green; planted `import AutofillEngine` in PolicyKit detected). `--all` clean.
- `verify.sh` exits 0 for every package: ❌ **BLOCKED — environment, not code.** See escalation E-001.

**Lesson (cost: ~2 fix-loop iterations):** early "exit 0" readings were `tail`'s exit status, not Swift's — pipelines without `pipefail` lie. `verify.sh` was rewritten to be exit-code strict with output-only-on-failure. Trust exit codes, never log absence.

**Next agent:** after the toolchain is repaired (E-001), run `Scripts/verify.sh --all`; if green, squash-merge the branch, move this file to `done/`, and P0-02 unblocks.
