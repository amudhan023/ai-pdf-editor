import Foundation

/// How badly a `PrivacyDashboardError` should be treated by a caller
/// (CLAUDE.md §15 shape, same pattern as `VaultAPI.VaultErrorRecoverability`).
public enum PrivacyDashboardErrorRecoverability: String, Sendable, Equatable {
    case retryable
    case userAction
    case fatal
}

/// Typed error taxonomy for this module (CLAUDE.md §15: no bare `catch {}`,
/// no `fatalError` on a user-reachable path).
public enum PrivacyDashboardError: Error, Sendable, Equatable {
    /// The typed confirmation name didn't match the profile being erased —
    /// a normal user-input mismatch, not a vault/system failure.
    case eraseConfirmationMismatch
    case underlyingVaultError(String)
    case auditLogUnavailable(String)

    public var userMessageKey: String {
        switch self {
        case .eraseConfirmationMismatch: "error.privacyDashboard.eraseConfirmationMismatch"
        case .underlyingVaultError: "error.privacyDashboard.vault"
        case .auditLogUnavailable: "error.privacyDashboard.auditLogUnavailable"
        }
    }

    public var recoverability: PrivacyDashboardErrorRecoverability {
        switch self {
        case .eraseConfirmationMismatch: .userAction
        case .underlyingVaultError: .retryable
        case .auditLogUnavailable: .retryable
        }
    }
}
