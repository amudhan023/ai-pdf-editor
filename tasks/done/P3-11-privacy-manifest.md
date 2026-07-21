# P3-11 — Privacy Manifest & Required-Reason API Declarations

**Epic:** E16 · **Primary package:** `App/` (+ each `Services/*.xpc` target) · **Complexity:** M · **Priority:** High

**Owner:** claude-agent · **Branch:** task/P3-11-privacy-manifest · **Claimed:** 1dce55042c906c284d34eefc072062ab57b9e0b3

## Journal

- Verified each declared category against the actual SwiftPM target graph (not just the directory): `App/Package.swift` pulls in `DocumentSession`, which pulls in `AtomicSave.swift` (file-timestamp reads for versioned-backup comparison) and its own `UserDefaults` usage (scroll position) — both already declared in the checked-out `App/PrivacyInfo.xcprivacy`, confirmed real rather than speculative.
- `Services/DocEngineService|InferenceService|VaultService` each depend only on `Packages/Platform`, which has zero required-reason API usage — their empty manifests are correct. `Packages/VaultStore/.../BackupManager.swift` does use file timestamps but isn't yet linked into `VaultService`'s target, so nothing to declare there today (flagged in the audit doc for whoever wires it in).
- Added `docs/specs/privacy-manifest-audit.md` (the artifact the acceptance criteria require) plus one-line pointers from `App/CLAUDE.md` and each `Services/*/README.md`.
- Added a `repo-checks` CI step asserting all four manifest files exist (Testing Requirements' "CI check ... if feasible").
- Not done: Xcode's Generate Privacy Report / archive-export validation, since there's no `.xcodeproj` in this repo (`App/CLAUDE.md`'s standing note) — no tool exists here to run that check against. Declarations were instead verified by hand against the real target graph, which is what that tool would have inspected. Flagging as a known scope cut rather than silently skipping it.

## Goal
Ship a correct `PrivacyInfo.xcprivacy` for the main app bundle and each XPC service, declaring every "required reason" API the binary touches, so Xcode/App Store Connect validation doesn't reject the build before a human ever reviews it.

## Background
Apple's Privacy Manifest requirement has been a hard, automated enforcement gate since May 2024 and tightened further for 2026 (mandatory Xcode 26 SDK, which this project already targets). It is not a policy judgment call like most of App Review — it is a static validation step: an undeclared required-reason API category fails the upload outright. The categories most likely to apply here: file-timestamp APIs (document metadata in DocumentSession), `UserDefaults` (app settings/preferences), disk-space APIs (model-pack download checks in InferenceHost), and possibly system-boot-time APIs. Each embedded XPC service is its own bundle and can carry its own manifest; the main app's manifest does not automatically cover them.

## Requirements
- Add `PrivacyInfo.xcprivacy` to the `App/` target and to each of `Services/DocEngineService`, `Services/InferenceService`, `Services/VaultService`, declaring: `NSPrivacyAccessedAPITypes` (with approved reason codes) for every required-reason API actually used, and `NSPrivacyCollectedDataTypes` reflecting what's true at the time of the audit (expected: none collected for MVP, since telemetry/crash reporting are separate opt-in paths handled in P3-09).
- Run Xcode's Product → Generate Privacy Report and resolve every flagged gap before this task is considered done.
- Treat this as a living declaration: re-run the audit whenever a task adds a new required-reason API usage (note this in the package `CLAUDE.md` files that touch such APIs), with a final comprehensive pass folded into P3-10's GA hardening burn-down.
- Do not declare more data collection than the code actually performs — the manifest is a `docs/CONSTITUTION.md` Article 13 (evidence over assertion) artifact, not boilerplate.

## Dependencies
- P0-07 (app target exists to attach a manifest to).
- Practically finalized alongside P3-10, once the codebase's required-reason API surface has stabilized — this task lands the mechanism and an accurate first-pass declaration; P3-10 re-validates it.

## Files Likely Affected
- `App/PrivacyInfo.xcprivacy` (new)
- `Services/DocEngineService/PrivacyInfo.xcprivacy`, `Services/InferenceService/PrivacyInfo.xcprivacy`, `Services/VaultService/PrivacyInfo.xcprivacy` (new)
- `docs/specs/privacy-manifest-audit.md` (new — running log of API usage → declared reason, so future tasks update it instead of leaving it stale)

## Acceptance Criteria
- Xcode's Generate Privacy Report shows zero undeclared required-reason API usage across the app and all three XPC service bundles.
- A test archive upload (or `xcodebuild -exportArchive` validation) does not fail on privacy-manifest grounds.
- `docs/specs/privacy-manifest-audit.md` lists every declared API category with the actual call site(s) that justify it — no speculative/unused declarations.

## Definition of Done
- Global DoD, plus: privacy manifest audit doc committed and cross-referenced from `App/CLAUDE.md` and each service's `CLAUDE.md`, with a note that adding a new required-reason API call requires updating both the manifest and the audit doc in the same PR.

## Testing Requirements
- Xcode Privacy Report run recorded (attach output or summary to the PR).
- CI check (if feasible under `Scripts/verify.sh` or a dedicated release-gate script) that fails when a manifest is missing from any of the four bundles.

## Documentation Updates
- `docs/specs/privacy-manifest-audit.md` (new); `App/CLAUDE.md` and each `Services/*/README.md` gain a one-line pointer to it.
