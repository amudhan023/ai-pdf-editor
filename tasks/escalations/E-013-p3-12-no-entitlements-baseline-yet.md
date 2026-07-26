# E-013 — P3-12 blocked: no `.entitlements` files or app-bundle sandboxing exist yet to audit

**Raised by:** attempted claim of P3-12 · **Severity:** blocks P3-12 only · **Status: OPEN**

## Evidence

- P3-12's Requirements assume existing `.entitlements` files for `App/`, `Services/DocEngineService`, `Services/InferenceService`, `Services/VaultService` that just need review/tightening ("no new capabilities added by this task").
- `find . -iname "*.entitlements"` returns nothing repo-wide. There is no `.xcodeproj`/`.xcworkspace` either — `App/Package.swift`'s own header comment says real `.app` bundle assembly (Info.plist, entitlements, code signing) is a separate packaging step, and that `Scripts/build-app-bundle.sh` is that step.
- Read `Scripts/build-app-bundle.sh`: it ad-hoc-signs the bundle (`codesign --force --sign -`) with no entitlements plist at all, and does not embed `Services/*` as XPC services inside the app bundle — they're standalone SwiftPM executables today, not bundled `.xpc` targets under `Contents/XPCServices/`.
- So P3-12's premise (shipped services with entitlements to minimize) doesn't hold yet. Its listed dependencies (P0-06/P1-08/P1-12) are about the XPC transport/service *packages* existing, not about sandbox/entitlement/bundle-embedding infrastructure existing — that gap isn't tracked by any dependency this task lists.

## Conclusion

Not a code defect in P3-12's own scope — it's a missing-prerequisite gap. Writing entitlements files from scratch here would itself be "new entitlements," which root `CLAUDE.md` §7.7 requires an ADR + human sign-off for — the opposite of what this task claims it's doing ("review/tighten, no new capabilities added").

## Decision needed (human)

Either: (a) treat "author the initial minimal entitlements + XPC-service bundle embedding" as its own prerequisite task/ADR before P3-12's audit can mean anything, or (b) defer P3-12 until app-bundle packaging work naturally produces a first entitlements baseline (e.g. as part of a future MAS-packaging task), and P3-12 becomes the *review* pass at that point, matching its original intent.

## Interim decision

P3-12 stays in `tasks/backlog/`, unclaimed. No other backlog task in phase-2/phase-3 has both its dependencies satisfied and a non-conflicting primary package right now (checked against `tasks/in-progress/`: P1-06/DocEngineHost+DocumentSession, P2-03/AutofillEngine, P2-08/IngestionPipeline all claimed).
