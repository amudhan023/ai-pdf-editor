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
