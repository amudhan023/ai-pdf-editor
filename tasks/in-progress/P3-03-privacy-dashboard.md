# P3-03 — Privacy Dashboard

**Owner:** claude-agent · **Branch:** task/P3-03-privacy-dashboard · **Claimed:** 328f3d9df8ea6f86aa6a17adac03791b5acb6025

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

## Journal

**Orient:** Picked up a prior session's in-progress work on this exact branch: `StorageSummaryService`, `ActivityTimelineViewModel`, `NetworkActivityViewModel`/`NetworkConnectionSettingsStore`, `VaultExportService`, `SecureEraseViewModel`, `VaultFieldCatalog`, and `PrivacyDashboardError` already existed uncommitted, plus one test file (`StorageSummaryServiceTests`). The placeholder `PrivacyDashboard.swift` module anchor had been deleted but the test referencing it (`PrivacyDashboardTests.swift`) was left behind, breaking the build.

**Plan:** (1) Remove the now-dead placeholder test. (2) Verify build/tests/boundary-lint green. (3) Fill the testing gap: the task's Testing Requirements call for view-model tests over synthetic audit streams, toggle-enforcement tests, and the two acceptance criteria (fresh-install zero network events + toggle prevents connection; secure erase renders vault unreadable) had no test coverage yet — added `ActivityTimelineViewModelTests`, `NetworkActivityViewModelTests` (incl. a fake-dialer toggle-enforcement test, since no real update-check/license-validation call site exists yet in this repo to stub), `VaultActionsTests` (export + secure-erase, including the post-shred `person(_:)` throws check). (4) Document the two known gaps (no person-enumeration API, network enforcement lives outside this package) in the package `CLAUDE.md`.

**Verify:** `Scripts/verify.sh PrivacyDashboard` → OK (build + 15 tests + boundary lint).

**Security/privacy self-audit:** Touches vault field presence (counts only, no values — `compareRead`), vault export (full field values, but only via an explicit user-initiated `.read`-ticketed export action, JSON-encoded as the sanctioned final-write boundary), and crypto-shred (destructive, gated by typed-name confirmation). No network calls; no values logged; `AuditLog` entries carry no values by construction.

**Architecture self-review (§6):** No type here duplicates an API-package concept (view-models wrap `VaultClient`/`AuditLogStore` calls, they don't reinvent them). No UI logic present yet (no `*UI` package exists for this task — out of this task's stated scope, which is `Sources/**` view-model/service layer only). No ARCHITECTURE.md edit needed.

**Snapshot tests:** Not added — no `*UI` package/views exist yet in this repo for this feature; the task's "Files Likely Affected" is `Sources/**` only, and there's no SwiftUI view target in this package to snapshot. Flagging as a gap for whichever follow-up task adds the actual dashboard UI.
