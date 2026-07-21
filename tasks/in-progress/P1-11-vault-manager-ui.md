# P1-11 — Vault Manager UI

**Owner:** claude-agent · **Branch:** task/P1-11-vault-manager-ui · **Claimed:** 65417584b235fbbef74bcf3a2ad7039a87f0d402

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

## Journal

**Orient:** Root CLAUDE.md; `Packages/VaultManagerUI/CLAUDE.md` (stale — lists only VaultAPI/PolicyKit, but `Scripts/import-allowlist.txt`, the enforced source, also allows SwiftUI/AppKit/os/OSLog; will fix in Document step). Read all of `VaultAPI`'s public surface (`VaultClient`, `FakeVaultClient`, `Person`, `ProfileField`, `FieldValue`/`FieldPath`, `HistoryEntry`, `PolicyTicket`, `SensitivityTier`, `RelationshipEdge`, `SecureBytes`, `VaultError`) and `PolicyKit`'s `PolicyRules`/`PolicyRequest`/`PolicyDecision`/`TicketMinter`. Read `tasks/done/P1-09-vault-lock-auth.md` (its "Not done" section explicitly hands the recovery-code-reveal UI and unlock-screen UI to whoever picks up this task) and `tasks/done/P1-10-vault-crud-history.md`.

**Key finding — ticket minting can't happen inside this package as designed:** `PolicyKit.TicketMinter.mint` needs a `CryptoKit.SymmetricKey`, but `VaultManagerUI`'s allowlist has no CryptoKit (by design — signing-key custody is Platform/Keychain's job, not a UI package's). `PolicyRules.decide` itself is pure Foundation+VaultAPI, no key needed, so I can still run the *real* decision table here. Plan: define a small `TicketIssuing` protocol in this package (`issue(operation:personID:scopedPaths:sensitivity:) async throws -> PolicyTicket`); ship a `FakeTicketIssuer` that runs `PolicyRules.decide` for real and, on `.grant`, builds a `PolicyTicket` directly with an empty signature — legitimate because `FakeVaultClient` documents that it "trusts `PolicyTicket.signature` unconditionally" (verification is PolicyKit's job, not the protocol's). The real signed-ticket wiring (composition root supplies a `TicketIssuing` backed by `TicketMinter` + a Keychain-sourced key) is App-layer/`[INTEGRATION]` follow-up, matching this task's own "FakeVaultClient first, then real service" framing — flagging it rather than faking a signature here.

**Plan:**
1. `Support/TicketIssuing.swift` — protocol + `FakeTicketIssuer` (wraps `PolicyRules.decide`, throws `.requireReauth`/`.deny` as typed errors).
2. `Support/AuthFreshnessClock.swift` — protocol + `FakeAuthFreshnessClock` tracking `lastAuthenticatedAt`, used by both the issuer (sensitivity gate) and the unlock/lock view model.
3. View models (SwiftUI-free, unit-testable against `FakeVaultClient`): `ProfileListViewModel` (list/create/delete person, relationships), `ProfileDetailViewModel` (section field CRUD incl. custom fields, masked-by-default + reveal-via-ticket, history-list CRUD with overlap detection), `VaultUnlockViewModel` (lock state, unlock ceremony, auto-lock idle timer, one-time recovery-code display gate).
4. Thin SwiftUI views wiring to the above (`VaultWindowView`, `ProfileSidebarView`, `SectionDetailView`, `FieldEditorView` per `FieldValueKind`, `HistoryListView`, `UnlockView`, `RecoveryCodeRevealView`) — `NSWindow.sharingType = .none` hook on the window for screenshot exclusion, applied where the window is actually created (composition root, out of this package's reach) — documented as a call-site contract in a doc comment since `VaultManagerUI` doesn't own window creation.
5. Tests: view-model unit tests against `FakeVaultClient` (create/edit/delete, locked-state rejection, reveal grant/deny/reauth, overlap warnings, custom-field paths, pasteboard-transiency of reveal). No XCUITest — same constraint every other UI task in this repo hits (`App/CLAUDE.md`: no real `.xcodeproj`, `swift package generate-xcodeproj` removed from this toolchain); no snapshot-testing dependency added either — grepped the repo, no existing snapshot convention/dependency exists anywhere, and CLAUDE.md §17's default answer to a new dependency is no for what view-model tests already cover. Both are scope cuts, not silent gaps — flagging here rather than fabricating either.
6. `docs/specs/m2-demo.md`: the ≤5-minute usability script (2-person family, relationships, passport + address history, custom field).
7. Update `Packages/VaultManagerUI/CLAUDE.md` (imports correction + new invariants), keep ≤60 lines.

**Risks:** file-size cap (~400 lines) on `ProfileDetailViewModel` given how much it owns (fields + history + reveal) — will split into `ProfileDetailViewModel` + `HistoryListViewModel` if it runs long. Pasteboard-transiency (CLAUDE.md §7.4) has no existing pasteboard helper in this package or `VaultAPI`/`PolicyKit` to reuse — will hand-roll a minimal `NSPasteboard` transient-type write with expiry inline rather than adding a new abstraction for one call site (ultra ponytail: one line beats a helper type for a single caller).
