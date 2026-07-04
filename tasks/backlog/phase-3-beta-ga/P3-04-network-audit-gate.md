# P3-04 — Automated Network Audit Release Gate

**Epic:** E14/E15 · **Primary package:** `Scripts/network-audit.sh` + CI · **Complexity:** M · **Priority:** High

## Goal
Automate PRD acceptance gate #4: a scripted full-feature walkthrough under packet capture that fails the release if any non-consented connection occurs.

## Background
ARCHITECTURE.md §6.1 "our own code" threat row: the zero-network claim must be reproducible evidence, not assertion. Also produces the artifact for the third-party audit (NFR-S3) and the published whitepaper (FR-5.5 groundwork).

## Requirements
- Harness: launch app in a controlled environment, drive the M0–M5 demo scripts via XCUITest/AppleScript (open, annotate, ingest, fill, export), capture per-process traffic (all four executables).
- Allowlist model: consented endpoints (update check off by default in test) — any other packet = failure with process attribution.
- Runs in `release.yml` as a blocking gate; produces a human-readable report artifact (for audit/whitepaper).
- Entitlement audit companion: script asserting no network entitlement on the three services.

## Dependencies
- P1-16, P2-05, P2-11 (needs the flows to drive); P0-02.

## Files Likely Affected
- `Scripts/network-audit.sh`; `.github/workflows/release.yml`; test driver in a `Tools/` target.

## Acceptance Criteria
- Clean run on current main; a planted test connection in a debug build is caught and attributed to the right process.
- Report artifact is publishable quality (endpoints, processes, verdict).

## Definition of Done
- Global DoD, plus: gate marked required in release workflow.

## Testing Requirements
- Positive (clean) and negative (planted leak) runs in CI.

## Documentation Updates
- docs/specs/network-audit.md (methodology — feeds the whitepaper).
