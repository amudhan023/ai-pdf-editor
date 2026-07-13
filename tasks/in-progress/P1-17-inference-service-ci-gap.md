# P1-17 — CI: wire Services/InferenceService into the `services` job

**Epic:** E12 · **Primary package:** `.github/workflows/ci.yml` · **Complexity:** S · **Priority:** Medium

**Owner:** claude-agent · **Branch:** task/P1-17-inference-service-ci-gap · **Claimed:** 07bc3d2d35bc2a388ea98276f33cebbdbf53081c

## Goal
`Services/InferenceService` (merged in P1-12) has never been built/tested by CI's `services` job — only `Services/DocEngineService` is listed. Add the missing step so it stops being silently unverified.

## Background
Discovered while wiring `Services/VaultService` into the same job for P1-08. The job's own header comment said "extend this list as P1-08/P1-12 add VaultService/InferenceService skeletons" but P1-12's PR never did so for InferenceService. Out of scope to fix as a drive-by inside the P1-08 PR (different task, already-merged code) — filed per CLAUDE.md §10/AGENT_LOOP.md §10.

## Requirements
- Add a `swift build --package-path Services/InferenceService && swift test --package-path Services/InferenceService` step to the `services` job in `.github/workflows/ci.yml`, mirroring the DocEngineService/VaultService steps.

## Dependencies
- None.

## Files Likely Affected
- `.github/workflows/ci.yml`

## Acceptance Criteria
- `services` job builds and tests `Services/InferenceService` on every PR.

## Definition of Done
- Global DoD (tasks/README.md).

## Testing Requirements
- CI run itself is the test (this is a CI-config-only change).

## Documentation Updates
- None beyond the workflow file itself.

## Journal

**Orient:** Read root CLAUDE.md, this task file, `.github/workflows/ci.yml` `services` job. Confirmed `Services/InferenceService` (Package.swift, Sources/, Tests/) exists and was genuinely missing from the `services` job — only DocEngineService and VaultService steps were present.

**Plan:** Add a third step to the `services` job mirroring the DocEngineService/VaultService pattern (`swift build --package-path ... && swift test --package-path ...`), and remove the now-stale NOTE comment pointing at this task file since the gap it describes is closed. No frozen seam, entitlement, or new dependency involved — CI-config-only change, single file.

**Implement:** Edited `.github/workflows/ci.yml`: added the `Scripts/verify.sh Services/InferenceService` step; removed the stale NOTE comment above the `services:` job key.

**Verify:** `swift build --package-path Services/InferenceService` and `swift test --package-path Services/InferenceService` both pass locally (1 integration test, `testServiceStartsSelfChecksAndIsKillable`). `Scripts/verify.sh`/`verify-integration.sh` don't apply here (they only target `Packages/*`, matching the existing DocEngineService/VaultService pattern which also bypasses them) — consistent with the task's own Testing Requirements ("CI run itself is the test"). YAML validity checked via `ruby -ryaml`.

**Harden:** Diff is minimal (3 added lines, 3 removed comment lines) and scoped entirely to `.github/workflows/ci.yml`. No dead code, no narrating comments added.

**Security/privacy self-audit:** No sensitive data touched — this is a CI workflow config change adding a build/test step for an existing service skeleton; no vault, document, or PII surface involved.

**Architecture self-review (G4):** No new type, no layering change, no ARCHITECTURE.md impact — purely closes a CI verification gap for already-merged code (P1-12).
