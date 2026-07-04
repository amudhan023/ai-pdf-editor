# P3-12 — XPC Entitlement Minimization & MAS Review Justification

**Epic:** E16 · **Primary package:** `[INTEGRATION]` — `Services/DocEngineService`, `Services/InferenceService`, `Services/VaultService`, `App/` · **Complexity:** M · **Priority:** High

## Goal
Audit and minimize the entitlements on all three XPC services and the main app for the Mac App Store build, and produce a written justification for App Review Notes, so the privilege-separated architecture reads as intentional and minimal rather than triggering a reviewer resolution-center request.

## Background
Guideline 2.4.5(v) governs exactly this project's shape — a sandboxed main app talking to differently-sandboxed XPC services — and it is explicitly an accepted pattern (this is how Preview and Safari do privilege separation). The risk is not the pattern; it is unclear or overly broad entitlements. Apple's own guidance is that unclear entitlement usage can trigger a request for written explanation, and `com.apple.security.temporary-exception.*` entitlements specifically are the most scrutinized and most often rejected class. Per ARCHITECTURE.md §6.3, each service should already carry the minimum entitlement set (no network, scoped file/container access only) — this task verifies that's actually true in the shipped build and documents why.

## Requirements
- Enumerate the actual `.entitlements` file for `App/`, `Services/DocEngineService`, `Services/InferenceService`, `Services/VaultService` as they exist at time of audit; confirm each has no network entitlement (per Constitution Art. 11) and no `temporary-exception` entries.
- For every entitlement present, write one sentence in the justification doc explaining the concrete capability it grants and why the service needs it (e.g., "DocEngineService: no persistent file entitlement — receives only security-scoped handles passed per-document from the main app").
- Confirm inter-process XPC communication works via the standard embedded-XPC-service mechanism (services bundled under the app, matching team ID / code signature) rather than any Mach-lookup exception.
- Produce the App Review Notes text block (ready to paste into App Store Connect at submission time) summarizing the architecture in reviewer-friendly terms, referencing the justification doc.

## Dependencies
- P0-06 (DocEngine.xpc exists), P1-08 (Vault.xpc exists), P1-12 (Inference.xpc exists) — this task audits real, built services, not a plan.

## Files Likely Affected
- `Services/DocEngineService/DocEngineService.entitlements`, `Services/InferenceService/InferenceService.entitlements`, `Services/VaultService/VaultService.entitlements`, `App/App.entitlements` (review/tighten, no new capabilities added by this task)
- `docs/specs/xpc-entitlement-justification.md` (new)

## Acceptance Criteria
- Zero `temporary-exception` entitlements in any of the four bundles.
- Every entitlement present has a corresponding one-line justification in the doc; no entitlement exists that isn't exercised by shipped code (dead/speculative entitlements removed).
- App Review Notes draft exists and reads clearly to someone with no prior context on this project.

## Definition of Done
- Global DoD, plus: justification doc reviewed against the actual `.entitlements` files (not written from memory of what they're *supposed* to contain).

## Testing Requirements
- Manual verification: launch the MAS-configuration build, exercise document open/fill/vault-unlock flows, confirm no sandbox-violation console logs (`sandboxd` denials) appear — a denial here means an entitlement is missing, which is the opposite failure mode from over-granting and should be fixed by adding the *specific* needed entitlement, not a broad one.

## Documentation Updates
- `docs/specs/xpc-entitlement-justification.md` (new); linked from `App/CLAUDE.md` and each service's `CLAUDE.md`.
