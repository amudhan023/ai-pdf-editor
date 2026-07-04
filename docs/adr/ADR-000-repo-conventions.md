# ADR-000 — Repository Conventions

**Status:** Accepted · **Task:** P0-01

## Context
The repo hosts a multi-process macOS app built almost entirely by autonomous Claude Code agents (docs/AGENT_LOOP.md). Conventions must make parallel agent work structurally safe.

## Decision
1. **One SPM package per architecture module** under `Packages/`, path-based dependencies only, per docs/REPO_STRUCTURE.md. 17 packages scaffolded; `Packages/*API/` and `Schemas/` are frozen seams (ADR + human review to change).
2. **Boundary enforcement is a portable shell checker** (`Scripts/check-boundaries.sh`) driven by `Scripts/import-allowlist.txt` — not SwiftLint custom rules as originally sketched in P0-01. Rationale: zero external tool dependency (SwiftLint is not installed on all machines/CI images), trivially auditable, and the allowlist file doubles as machine-readable architecture documentation. SwiftLint may be layered on later (P0-02) for style; boundaries stay with the shell checker either way.
3. **Verification contract:** `Scripts/verify.sh <Package>` = build + tests + boundary lint; identical locally and in CI.
4. **Swift 6.0 tools version, macOS 14 minimum** (matches PRD NFR-C1).
5. **Git LFS** declared via `.gitattributes` for binary fixtures/prebuilts; git-lfs must be installed before P0-03/P0-08 add binaries (bootstrap warns).
6. **Task workflow** per tasks/README.md; local execution uses branch → squash-merge to `main` (PR machinery attaches when a remote exists; the commit/branch conventions are identical).

## Consequences
- Agents cannot create hidden cross-package coupling; violations fail `verify.sh` and CI.
- Adding a package = generator-style scaffold (Package.swift + placeholder + smoke test + CLAUDE.md + allowlist line) and an ADR if it changes the architecture module map.
