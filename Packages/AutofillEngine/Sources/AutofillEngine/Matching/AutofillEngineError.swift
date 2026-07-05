import Foundation

/// Typed error taxonomy for this module (CLAUDE.md §15 shape) — mirrors
/// the sibling `InferenceError`/`VaultError` self-contained precedent
/// since no shared `VaultformError` protocol exists yet.
public enum AutofillEngineError: Error, Sendable, Equatable {
    case aliasDictionaryUnavailable(reason: String)
}
