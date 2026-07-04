# P0-15 — Dedicated Integration-Test CI Gate

**Epic:** E1 · **Primary package:** none (`.github/workflows/ci.yml` + `Scripts/`) · **Complexity:** M · **Priority:** High

## Goal
Add a CI stage that runs cross-boundary/integration-tier tests as its own labeled, required job — distinct from the existing per-package unit-test step — so "integration tests pass" is a real, checkable CI fact rather than an assumption folded silently into `swift test`.

## Background
`Scripts/verify.sh` (wired into `.github/workflows/ci.yml`'s `verify` job) already runs `swift build` + `swift test` + boundary lint per touched package — that's the unit-test tier, and it already gates `ci-status`. What's missing is a separate tier for tests that exercise a contract *across* a boundary rather than inside one package: today the closest examples are `VaultAPI`'s and `PDFEngineAPI`'s `*ConformanceTests` (a `Fake*` client verified against the full protocol contract, per CLAUDE.md §9's "Services → conformance suites" tier), but they currently just run bundled inside each package's own unit-test target with no separate label, and there's no repo-wide end-to-end suite at all (`Scripts/corpus-roundtrip.sh`, the planned round-trip/no-corruption gate, doesn't exist yet — that's P1-16's job, blocked on the atomic-save path existing).

This task is scoped to the *mechanism* (a real, labeled, required "integration-tests" CI job) using what already exists (the conformance suites) as its first content — not to building corpus-roundtrip.sh itself, which stays P1-16's job and slots into this same job once it lands.

## Requirements
- Add an `integration-tests` job to `.github/workflows/ci.yml` that explicitly runs the `*ConformanceTests` targets (by test-target/filter name, e.g. `swift test --filter ConformanceTests` per applicable package) as its own step, separate from and in addition to the per-package unit-test step in `verify`.
- Document the convention going forward in CLAUDE.md §9: any test file/target matching `*ConformanceTests` or `*IntegrationTests` is picked up by this job; package authors adding a Session/Service-level integration test name it accordingly so it's included without further CI edits.
- Wire `integration-tests` into the `ci-status` aggregator (same all-or-nothing rule as `verify`/`repo-checks`: required, not skippable except when genuinely no such test exists yet).
- Leave `Scripts/corpus-roundtrip.sh` as a documented future slot in this same job (a comment + a `# TODO(P1-16)`-style marker, not a stub script) — don't fabricate a script that doesn't do anything yet.

## Dependencies
- None to start (uses existing `VaultAPI`/`PDFEngineAPI` conformance suites as first content). P1-16 later extends this job's content, doesn't block creating the job itself.

## Files Likely Affected
- `.github/workflows/ci.yml`, `CLAUDE.md` §9, `docs/AGENT_LOOP.md` (Step 4/8a references to what `ci-status` actually covers).

## Acceptance Criteria
- `ci-status` fails if a `*ConformanceTests` target fails, verified by a deliberately-broken conformance test in a scratch commit during development (reverted before merge).
- A PR that touches zero packages with conformance tests still shows `integration-tests` as a green/skip, not a silent absence — same pattern as `verify`'s current skip-when-no-packages-touched handling.
- CLAUDE.md/AGENT_LOOP.md accurately describe what "integration test" means in this repo's CI today (no overclaiming corpus-roundtrip coverage that doesn't exist).

## Definition of Done
- Global DoD, plus: this PR is not `[INTEGRATION]`/security/API-schema itself, but it does change what `ci-status` gates for every future PR — call that out explicitly in the PR description even if it doesn't fall under a CLAUDE.md/AGENT_LOOP.md text carve-out.

## Testing Requirements
- CI workflow change is its own test: a run against a deliberately-failing conformance test target, and a run against the current green state, both attached as evidence (per Constitution Art. 13).

## Documentation Updates
- CLAUDE.md §9 (test pyramid — name the new required tier and the naming convention that feeds it), `docs/AGENT_LOOP.md` (Step 4 test-running guidance).
