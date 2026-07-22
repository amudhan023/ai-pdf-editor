# P3-13 — Export Compliance Confirmation (SQLCipher Crypto Backend + App Store Connect Classification)

**Epic:** E16 · **Primary package:** `Packages/VaultStore` (+ `App/` Info.plist) · **Complexity:** S · **Priority:** High

## Goal
Confirm the vault's cryptography stays within Apple's standard/exempt encryption category, and complete the App Store Connect export-compliance declaration correctly, so submission isn't blocked or mis-filed on encryption grounds.

## Background
SQLCipher has historically shipped with an OpenSSL crypto backend on some platforms/distributions, which would push the app out of Apple's "standard, exempt" cryptography bucket and into a real self-classification/export-filing obligation. The official "SQLCipher for Apple" distribution instead links `CommonCrypto`/`Security.framework` as its backend by default on macOS 10.15+, which stays inside the exemption (encryption used solely for authentication/data protection via standard OS-provided crypto APIs). This task is a verification-and-paperwork task, not new cryptography — it confirms P1-08's actual dependency choice matches the exempt configuration and completes the resulting Info.plist/App Store Connect steps.

## Requirements
- Confirm `Packages/VaultStore`'s SQLCipher dependency resolves to the official Apple-targeted distribution (links `Security.framework`/`CommonCrypto`), not a community fork that bundles or links OpenSSL directly.
- Set `ITSAppUsesNonExemptEncryption` appropriately in `App/Info.plist` (expected: `NO`, or `YES` with the standard-exemption self-classification — determine which based on the confirmed backend, do not guess).
- Complete the App Store Connect export compliance questionnaire for the app record, selecting the standard/exempt category with the rationale documented.
- Fold this confirmation into the same pre-GA legal review the PRD already calls for under Risk R8 (COPPA posture, state privacy laws) — export compliance is a natural addition to that same review pass, not a separate one.

## Dependencies
- P1-08 (VaultStore/SQLCipher integration exists to audit).

## Files Likely Affected
- `Packages/VaultStore/Package.swift` (verify dependency pin only — no change expected unless the wrong distribution was used, in which case correct it here)
- `App/Info.plist` (`ITSAppUsesNonExemptEncryption` key)
- `docs/specs/export-compliance.md` (new — records the backend confirmation, the classification decision, and the reasoning, so it's evidence rather than assumption)

## Acceptance Criteria
- Documented confirmation (with the actual resolved package/version) that SQLCipher links `CommonCrypto`/`Security.framework` on this build, not OpenSSL.
- `ITSAppUsesNonExemptEncryption` set correctly and consistently with the App Store Connect questionnaire answer.
- No "Missing Compliance" warning on the next TestFlight/App Store Connect build upload.

## Definition of Done
- Global DoD, plus: sign-off noted alongside the PRD's Risk R8 legal-review item, not left as a standalone unreviewed technical claim.

## Testing Requirements
- Build-log/dependency-graph inspection confirming the linked crypto library; no automated test applicable beyond that verification.

## Documentation Updates
- `docs/specs/export-compliance.md` (new); PRD Risk R8 mitigation note updated to reference it.
