# P1-11 — Vault Manager UI

**Epic:** E9 · **Primary package:** `Packages/VaultManagerUI` · **Complexity:** L · **Priority:** High

## Goal
The vault window: profile list (persons/org), section-organized field editing, manual entry, custom fields, history-list editors, sensitivity masking with re-auth reveal, unlock/lock UX, recovery-code onboarding.

## Background
PRD FR-2.1–2.5, M2 milestone centerpiece. Built entirely against `FakeVaultClient` first, then real service — no direct VaultStore imports (boundary rule).

## Requirements
- Profile sidebar (add person/org, relationships editor); section detail views with typed field editors (dates, enums, lists).
- History-list UX: entries with date ranges, overlap warnings.
- Sensitive fields masked by default; reveal requires re-auth (PolicyKit flow); screenshot exclusion on vault windows (`sharingType`).
- Unlock screen (Touch ID prompt), auto-lock behavior, recovery-code one-time display ceremony.

## Dependencies
- P0-09 (builds on fake); integrates against P1-09/P1-10 before M2.

## Files Likely Affected
- `Packages/VaultManagerUI/Sources/**`.

## Acceptance Criteria
- Usability script: create 2-person family with relationships, passport + address history, custom field — ≤ 5 minutes, no documentation.
- Masked values never hit the pasteboard un-transiently; reveal events logged.

## Definition of Done
- Global DoD, plus: M2 demo script in docs/specs/m2-demo.md.

## Testing Requirements
- View-model unit tests against FakeVaultClient (incl. locked-state handling); snapshot tests; XCUITest for unlock→edit→lock flow.

## Documentation Updates
- Package `CLAUDE.md`.
