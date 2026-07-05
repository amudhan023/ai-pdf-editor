# P1-09 — Vault Lock/Unlock, Touch ID & Auto-Lock

**Owner:** claude-agent · **Branch:** task/P1-09-vault-lock-auth · **Claimed:** 59fe7007f4d0c53c5ada62618e8312f7b5288b50

**Epic:** E8 · **Primary package:** `Packages/VaultStore` (+ `Packages/Platform` LAContext wrapper) · **Complexity:** M · **Priority:** Critical

## Goal
Full lock-state machine: unlock via Touch ID/Apple Watch/password through LocalAuthentication, idle auto-lock, lock-on-sleep, auth-freshness signal for PolicyKit's sensitive gating.

## Background
ARCHITECTURE.md §6.2: LAContext success → SE unwraps master key inside Vault.xpc. Auth freshness feeds the PolicyKit `requireReauth` rule (P0-10). Recovery-code generation + one-time display flow included here (backend + minimal UI hook).

## Requirements
- Lock states (locked / unlocked / unlocking) as an actor-owned state machine; `VaultDidLock/Unlock` domain events.
- Configurable idle timeout; lock on system sleep/screen lock; immediate manual lock.
- Auth-freshness timestamp exposed to PolicyKit inputs; re-auth flow for Sensitive reads.
- Recovery code: generate, wrap master key, one-time reveal API, verify-and-unlock path (biometry reset survival).

## Dependencies
- P1-08.

## Files Likely Affected
- `Packages/VaultStore/Sources/Lock/**`; `Packages/Platform/Sources/Auth/**`.

## Acceptance Criteria
- Key material provably zeroized on lock (test hook inspects); operations while locked return typed `vaultLocked` errors.
- Recovery code unlocks after simulated Keychain/biometry loss in test harness.

## Definition of Done
- Global DoD.

## Testing Requirements
- State-machine unit tests (all transitions); freshness-window property tests with PolicyKit; recovery-path integration test.

## Documentation Updates
- docs/specs/vault-security-ux.md (lock behavior matrix for later UI tasks).

## Journal

**Orient:** Root CLAUDE.md; this task file; `Packages/VaultStore/CLAUDE.md` + `Packages/Platform/CLAUDE.md`; ARCHITECTURE.md §6.2 (cited in Background). P1-08 had already landed `VaultLockController`/`LockedBytes`/`MasterKeyManager`/`RecoveryCode` (locked/unlocked only, no events, no idle timeout, no auth-freshness) plus a `Platform/Auth/LocalAuthenticator.swift` (LAContext wrapper + error mapping) and its test — both untracked, evidently started by a prior session of this same task before a restart. Picked up from there rather than re-doing it.

**Plan:**
1. Add an internal `VaultLockPhase` (locked/unlocking/unlocked) to `VaultLockController` — kept out of `VaultAPI.VaultLockState` (frozen seam) since `VaultClient` consumers only need locked/unlocked; `unlocking` reads as `.locked` through that projection.
2. Wire `VaultLockEvent` (already added) into the controller via `nonisolated let events: AsyncStream<VaultLockEvent>`.
3. Add `lock(reason:)` (default `.manual`), idle-timeout (`setIdleTimeout`/`noteActivity`, cancel-and-restart `Task.sleep`, no `DispatchQueue`), `authFreshness()` (`PolicyKit.AuthFreshness`, VaultStore already depends on PolicyKit+Platform), and `reauthenticate(using:reason:)` (re-runs `LocalAuthenticating` without touching keys).
4. System-sleep/screen-lock hook: exposed as `lock(reason: .systemSleepOrScreenLock)` only — actual `NSWorkspace` notification wiring is App/Presentation-layer, outside `VaultStore`/`Platform`'s boundaries; documented as out-of-scope in the new spec.
5. Tests: state-machine transition (locked→unlocking→unlocked, via a `SlowKeyWrappingProvider` test double to make the transient phase observable deterministically), domain-event emission, idle-timeout auto-lock + activity deferral, auth-freshness set/clear on unlock/lock, `reauthenticate` (success + locked + failure paths), recovery-code unlock after simulated SE/biometry loss (`seBox.destroy()`), and a `PolicyRules.decide` integration test across freshness windows/elapsed times.

**Verify:** `Scripts/verify.sh VaultStore` — OK. `Scripts/verify.sh Platform` — OK (needed one fix: `LocalAuthenticatorTests.swift` was missing `import LocalAuthentication`, so `LAError` didn't resolve). `Scripts/verify-integration.sh` — clean skip on both (no `*Conformance`/`*Integration` classes touched).

**Harden notes:** `AsyncStream.makeStream` compiles at the tools-version 6.0 required minimum. Multiple `XCTAssertEqual`/`XCTAssertNil`/`XCTUnwrap` calls needed the `await`ed value hoisted to a `let` first — those macros' message parameter is an autoclosure, which can't contain `await` directly. `events` had to be `nonisolated` (an `AsyncStream` handle is safe to read across the actor boundary; only production/consumption needs isolation, which the stream itself already provides).

**Security/privacy self-audit:** touches vault master key handling (mlock'd `LockedBytes`) and the auth-freshness signal PolicyKit's Sensitive-tier gate reads. No new logging added; no key material or freshness timestamps cross a log/audit boundary in this diff — `authFreshness()`/`reauthenticate` only ever return/consume in-memory values.

**Architecture self-review (G4 judgment layer):**
1. No new type duplicates an API-package concept — `VaultLockPhase` is deliberately package-internal precisely to avoid duplicating/widening `VaultAPI.VaultLockState`.
2. No logic placed in a layer that'll need moving — idle-timeout/reauth/freshness all live in the same actor that already owns lock state; the one thing punted (system-sleep OS hook) is explicitly named as App-layer's job, not half-built here.
3. ARCHITECTURE.md doesn't need editing — §6.2 already describes this shape at the level of detail it operates at.

**Not done / follow-up:** the recovery-code one-time-reveal *UI* and the actual `NSWorkspace` sleep/screen-lock notification wiring are UI/App-layer work, out of `VaultStore`/`Platform`'s primary-package scope for this task — flagged in `docs/specs/vault-security-ux.md`'s "Out of scope" section for whichever task picks up the lock-screen UI.
