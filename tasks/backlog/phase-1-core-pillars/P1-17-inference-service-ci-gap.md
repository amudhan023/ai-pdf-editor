# P1-17 — CI: wire Services/InferenceService into the `services` job

**Epic:** E12 · **Primary package:** `.github/workflows/ci.yml` · **Complexity:** S · **Priority:** Medium

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
