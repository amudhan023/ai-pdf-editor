# P3-06 — Direct Distribution: Notarization, Sparkle & Release Pipeline

**Epic:** E16 · **Primary package:** `.github/workflows/release.yml` + `App/` update integration · **Complexity:** M · **Priority:** High

## Goal
The non-MAS channel: hardened, notarized, stapled DMG builds with Sparkle 2 (EdDSA-signed appcast) auto-updates, produced by a reproducible release pipeline that also drives the MAS submission build.

## Background
R11 mitigation: dual distribution from day 1. Update check is an enumerated network call — off until first-run consent, toggleable, and visible in the Privacy Dashboard (coordinate keys with P3-03).

## Requirements
- Release pipeline: version stamping, archive both channels, codesign all executables (app + 3 XPC services) with Hardened Runtime, notarize + staple, DMG packaging, appcast generation + EdDSA signing, gated by P3-04 network audit + corpus round-trip suite.
- Sparkle integration: consented update checks, delta updates, staged rollout percentage support.
- MAS variant: sandbox-profile differences handled by build configuration, StoreKit instead of Sparkle/licensing.
- Rollback story: previous-version DMGs retained and re-signable.

## Dependencies
- P0-02, P3-04, P3-05.

## Files Likely Affected
- `.github/workflows/release.yml`; `Scripts/release/**`; `App/` (Sparkle wiring, channel flags).

## Acceptance Criteria
- One-command release candidate: DMG installs and launches clean on a fresh macOS VM (Gatekeeper happy); update from vN-1 → vN via appcast works.
- Both channel builds pass the network audit with their respective allowlists.

## Definition of Done
- Global DoD, plus: release runbook docs/specs/release-runbook.md.

## Testing Requirements
- VM install/update tests; signature verification of all nested executables; appcast tamper test (bad signature refused).

## Documentation Updates
- Release runbook; root `CLAUDE.md` release section.
