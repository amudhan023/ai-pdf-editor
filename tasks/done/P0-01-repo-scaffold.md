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

---
## Journal update — verify.sh retry after CLT reinstall

**Progress:** E-001 (broken CLT ManifestAPI) is resolved — user reinstalled CLT (swiftc 6.0.3 → 6.3.3). `swift build` now succeeds for every package.

**New blocker found (E-002, not a code defect):** `swift test` fails for all 17 packages — `no such module 'XCTest'`. Diagnosed via a clean-room control package outside the repo: `import Testing` (Swift Testing) *also* fails the same way. Neither test framework is present. Confirmed no `/Applications/*.app` Xcode install exists. Root cause: on macOS, both XCTest.framework and Testing.framework ship inside Xcode.app, never inside standalone Command Line Tools, on any version — this is a permanent packaging boundary, not a broken install. Filed as `tasks/escalations/E-002-no-xctest-without-xcode.md`; did not burn fix-loop strikes attempting code-side workarounds since the cause was cleanly identified as environmental on first probe (AGENT_LOOP §4 fix-loop applies to fixable failures — this is diagnosis, not iteration).

**Did not do:** did not weaken `verify.sh` to skip/tolerate the missing test framework — that would be a red-line violation (CLAUDE.md §14, Constitution Art. 12), and would silently stop catching real regressions the moment a properly-provisioned (Xcode-installed) machine or CI runner is used.

**Propagated the fact so it's never re-diagnosed (TOKEN_EFFICIENCY §7):**
- `Scripts/bootstrap.sh` CLT-detection warning rewritten to state the test-framework gap explicitly and point at E-002.
- Every package `CLAUDE.md` Gotchas line updated with the same one-liner + pointer.
- Added root `.gitignore` (`.build/`, `.swiftpm/`, etc.) — build artifacts were previously untracked but unguarded against accidental `git add -A`.

**Status: still BLOCKED.** Acceptance criterion "`verify.sh` exits 0 for every package" cannot be met on this machine without a full Xcode install (~7-12GB, App Store). Boundary-lint criterion remains fully met. Task stays in `in-progress/`; not merging with a failing acceptance criterion.

**Next agent / human:** install full Xcode per E-002, `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, accept license, then `Scripts/verify.sh --all`. If green: rebase branch on main, squash-merge, move this file to `done/`.

---
## Journal update — E-002 resolved, full Xcode installed

**Unblocked:** human operator installed full Xcode (26.6). `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; `swift --version` → Swift 6.3.3.

**Both acceptance criteria now met:**
- `Scripts/verify.sh --all` → `verify: ALL PACKAGES OK` (build + test + boundary-lint green for all 17 packages).
- `Scripts/check-boundaries.sh --self-test` → passes (planted violation still detected).

E-001 and E-002 can be considered resolved for this machine; leaving both escalation files in place as-is (historical record + still relevant for any other CLT-only machine, per their own "standing note for future agents").

**Closing this task:** moving to `done/` in the same PR as this update. No CI/branch-protection dependency here (this is P0-01 itself, not P0-02) — `verify.sh --all` passing locally is the acceptance criterion, now demonstrably true.
