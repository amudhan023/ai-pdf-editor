# Vault Lock/Unlock UX — Behavior Matrix

**Owner of this fact:** this document. `VaultStore`'s `Lock/VaultLockController.swift` implements the state machine below; this is the reference for later UI tasks (lock screen, re-auth sheet, recovery-code reveal/entry) to build against without re-deriving the contract from source. ARCHITECTURE.md §6.2 is the design rationale; this doc is the concrete state/event/transition table (P1-09).

## States

`VaultLockController` tracks a three-phase internal state (`VaultLockPhase`, package-internal — not part of the frozen `VaultAPI.VaultLockState` seam):

| Phase | Meaning | `VaultClient.lockState()` reads as |
|---|---|---|
| `locked` | No key material resident; vault operations throw `VaultError.vaultLocked` | `.locked` |
| `unlocking` | An unlock attempt (SE or recovery-code path) is in flight | `.locked` |
| `unlocked` | Master key + derived keys resident in `mlock`'d `LockedBytes`; auth-freshness timestamp set | `.unlocked` |

`unlocking` is deliberately not exposed through the frozen `VaultClient` protocol — no read/write path is available until the transition actually completes, so external consumers only need locked/unlocked. UI that wants a distinct "unlocking…" spinner state should watch `VaultLockController.events` (below) rather than polling `lockState()`.

## Domain events

`VaultLockController.events: AsyncStream<VaultLockEvent>`:

- `.didUnlock(at: Date)` — emitted once a `locked` → `unlocked` transition completes (either unlock path).
- `.didLock(reason: VaultLockReason, at: Date)` — emitted on every transition into `locked`.

`VaultLockReason` distinguishes why a lock happened, for UI/audit consumers that want to say "you were signed out because you were idle" vs. "you locked the vault":

| Reason | Trigger |
|---|---|
| `.manual` | `lock()` called with no reason (the default) — explicit user action |
| `.idleTimeout` | No `noteActivity()` call within the configured idle window |
| `.systemSleepOrScreenLock` | Caller (App/Presentation layer — outside this package) reports a system sleep/screen-lock signal via `lock(reason: .systemSleepOrScreenLock)` |

## Unlock paths

| Path | Entry point | Survives SE/biometry reset? |
|---|---|---|
| Primary (Secure Enclave) | `unlock()` → `MasterKeyManager.unlock()` → SE unwrap, gated by the key's own access control (biometric/password prompt) | No |
| Recovery code | `unlock(recoveryCode:)` → `MasterKeyManager.unlock(recoveryCode:)`, HKDF-derived wrapping key independent of the SE | Yes — this is the entire reason it exists |

Recovery code generation (`MasterKeyManager.provision()`) returns the plaintext code exactly once, for a one-time-display UI the caller owns; nothing in `VaultStore` persists the plaintext. The later UI task building that reveal screen should treat the returned `RecoveryCode.plaintext` as un-recoverable after that call returns — there is no "show it again" API by design.

## Idle timeout

- `setIdleTimeout(_:)` configures the window (`nil` disables auto-lock on idle).
- `noteActivity()` pushes the deadline back; call it from any user-visible interaction while unlocked.
- Implemented as a cancel-and-restart `Task.sleep` per activity call (no `Timer`/`DispatchQueue`), so repeated activity is cheap and never leaks a task per call.

## Auth freshness / re-auth

- `authFreshness() -> PolicyKit.AuthFreshness?` is `nil` while locked; set to `Date()` on every successful unlock and cleared on lock.
- `reauthenticate(using:reason:)` re-runs a `LocalAuthenticating` prompt (Touch ID/Apple Watch/password via `Platform.LAContextAuthenticator`) and bumps the freshness timestamp **without** touching key material — this is the path a Sensitive-tier `PolicyRules.decide` `.requireReauth` result should drive the UI to call.
- Throws `VaultError.vaultLocked` if called while locked (there is nothing to refresh); propagates the authenticator's `LocalAuthenticationError` on cancellation/failure.

## Out of scope here (later tasks)

- Actual OS hooks for system sleep/screen-lock (`NSWorkspace` notifications) — App/Presentation-layer wiring that calls `lock(reason: .systemSleepOrScreenLock)`; outside `VaultStore`/`Platform`'s boundaries.
- The lock screen, re-auth sheet, and recovery-code reveal/entry UI themselves — `*UI` package work.
