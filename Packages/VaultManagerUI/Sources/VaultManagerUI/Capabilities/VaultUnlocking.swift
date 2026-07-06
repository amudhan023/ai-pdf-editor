import Foundation

/// Why a biometric/recovery-code unlock attempt failed. Distinct from
/// `VaultAPI.VaultError` (which models `VaultClient` operation failures,
/// not the unlock ceremony itself — `VaultClient` deliberately has no
/// unlock method, see its doc comment).
public enum VaultUnlockError: Error, Sendable, Equatable {
    case biometricsUnavailable
    case biometricsFailed
    case invalidRecoveryCode
    case cancelled
}

/// Capability seam for the unlock/lock ceremony. `VaultManagerUI` has no
/// `LocalAuthentication`/`Security` import allowance (see
/// `Scripts/import-allowlist.txt`) — Touch ID and the real lock/unlock
/// state machine are `Platform`/`Vault.xpc`'s job (CLAUDE.md §3.2); this
/// package only depends on the capability's shape, exposed by whatever the
/// composition root wires in.
public protocol VaultUnlocking: Sendable {
    func unlockWithBiometrics() async throws
    func unlockWithRecoveryCode(_ code: String) async throws
    func lock() async
}
