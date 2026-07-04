# P3-03 — Privacy Dashboard

**Epic:** E14 · **Primary package:** `Packages/PrivacyDashboard` · **Complexity:** M · **Priority:** High

## Goal
The trust surface (PRD FR-5.2): what's stored (field counts by section/person), the processing log (ingestions/fills from AuditLog), and network activity disclosure with per-connection toggles.

## Background
This window is the product's privacy claim made inspectable. Reads AuditLog (P1-15) and vault summaries (count-only compare-grants); displays the network ledger (should read "none" beyond the enumerated, toggleable items: update check, license validation).

## Requirements
- Storage view: per-person/section field counts, attachment count/size, last-modified — counts only, no values without normal vault unlock flow.
- Activity view: filterable AuditLog timeline (ingestions, fills, vault access, auth events) with chain-verification status indicator.
- Network view: enumerated permitted connections with on/off toggles (settings-backed), live last-contact timestamps, and a "verify offline" explainer (airplane-mode walkthrough).
- Vault actions: export-vault entry point (JSON schema export, MVP-level) and secure-erase (crypto-shred) with typed-confirmation ceremony.

## Dependencies
- P1-15, P1-10.

## Files Likely Affected
- `Packages/PrivacyDashboard/Sources/**`.

## Acceptance Criteria
- Fresh install → dashboard shows zero network events; toggling update-check off provably prevents the connection (integration test with network stub).
- Secure erase from dashboard renders vault unreadable (reuses P1-08 verification).

## Definition of Done
- Global DoD.

## Testing Requirements
- View-model tests over synthetic audit streams; toggle-enforcement integration tests; snapshot tests.

## Documentation Updates
- Package `CLAUDE.md`; user-facing privacy explainer copy reviewed against ARCHITECTURE.md claims.
