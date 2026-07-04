import Foundation

/// How badly a `VaultError` should be treated by a caller (CLAUDE.md §15
/// shape). Self-contained per module rather than depending on a shared
/// `VaultformError` protocol, since none exists yet in the repo — see
/// `PDFEngineAPI.PDFEngineError`'s identical precedent.
public enum VaultErrorRecoverability: String, Sendable, Codable, Equatable {
    case retryable
    case userAction
    case fatal
}

/// Typed error taxonomy for this module.
public enum VaultError: Error, Sendable, Codable, Equatable {
    /// Normal state (CLAUDE.md §15: "vault-locked is a normal state, not an
    /// error condition") — still modeled as a typed error so every call
    /// site is forced to handle it via the standard `throws` path rather
    /// than a separate out-of-band state check.
    case vaultLocked
    case personNotFound(PersonID)
    case fieldNotFound(FieldPath)
    case historyEntryNotFound(UUID)
    case relationshipNotFound
    case ticketExpired
    case ticketOperationMismatch(expected: VaultOperation, got: VaultOperation)
    case ticketScopeMismatch(operation: VaultOperation, path: FieldPath?)
    case invalidFieldPath(String)
    case cryptoShredFailed(reason: String)

    public var userMessageKey: String {
        switch self {
        case .vaultLocked: "error.vault.locked"
        case .personNotFound: "error.vault.personNotFound"
        case .fieldNotFound: "error.vault.fieldNotFound"
        case .historyEntryNotFound: "error.vault.historyEntryNotFound"
        case .relationshipNotFound: "error.vault.relationshipNotFound"
        case .ticketExpired: "error.vault.ticketExpired"
        case .ticketOperationMismatch: "error.vault.ticketOperationMismatch"
        case .ticketScopeMismatch: "error.vault.ticketScopeMismatch"
        case .invalidFieldPath: "error.vault.invalidFieldPath"
        case .cryptoShredFailed: "error.vault.cryptoShredFailed"
        }
    }

    public var debugDescription: String {
        switch self {
        case .vaultLocked: "vault is locked"
        case .personNotFound(let id): "person not found: \(id.value)"
        case .fieldNotFound(let path): "field not found: \(path)"
        case .historyEntryNotFound(let id): "history entry not found: \(id)"
        case .relationshipNotFound: "relationship edge not found"
        case .ticketExpired: "policy ticket expired or not yet valid"
        case .ticketOperationMismatch(let expected, let got):
            "policy ticket operation mismatch: expected \(expected.rawValue), got \(got.rawValue)"
        case .ticketScopeMismatch(let operation, let path):
            "policy ticket does not cover \(operation.rawValue) for \(path.map(String.init(describing:)) ?? "<person-scope>")"
        case .invalidFieldPath(let raw): "invalid field path: \(raw)"
        case .cryptoShredFailed(let reason): "crypto-shred failed: \(reason)"
        }
    }

    public var recoverability: VaultErrorRecoverability {
        switch self {
        case .vaultLocked: .userAction
        case .personNotFound, .fieldNotFound, .historyEntryNotFound, .relationshipNotFound, .invalidFieldPath:
            .userAction
        case .ticketExpired, .ticketOperationMismatch, .ticketScopeMismatch: .retryable
        case .cryptoShredFailed: .fatal
        }
    }
}
