import Foundation

/// How badly an `InferenceError` should be treated by a caller (CLAUDE.md
/// §15 shape). Self-contained per module — identical precedent to
/// `VaultAPI.VaultErrorRecoverability`/`PDFEngineAPI.PDFEngineError`, since
/// no shared `VaultformError` protocol exists yet in the repo.
public enum InferenceErrorRecoverability: String, Sendable, Codable, Equatable {
    case retryable
    case userAction
    case fatal
}

/// Typed error taxonomy for this module.
public enum InferenceError: Error, Sendable, Codable, Equatable {
    /// No installed/registered model satisfies this capability for the
    /// caller's hardware tier — a real condition (e.g. no model pack
    /// bundled yet), not a bug.
    case capabilityUnavailable(InferenceCapability, HardwareTier)
    /// A model pack failed checksum or signature verification
    /// (CLAUDE.md §7.6: "never load a model from an unverified path").
    case modelPackUnverified(reason: String)
    case modelPackNotFound(InferenceCapability)
    /// A background request was cooperatively cancelled to let an
    /// interactive request preempt it; callers may resubmit.
    case requestCancelled
    case memoryCapExceeded
    case adapterFailure(reason: String)

    public var userMessageKey: String {
        switch self {
        case .capabilityUnavailable: "error.inference.capabilityUnavailable"
        case .modelPackUnverified: "error.inference.modelPackUnverified"
        case .modelPackNotFound: "error.inference.modelPackNotFound"
        case .requestCancelled: "error.inference.requestCancelled"
        case .memoryCapExceeded: "error.inference.memoryCapExceeded"
        case .adapterFailure: "error.inference.adapterFailure"
        }
    }

    public var debugDescription: String {
        switch self {
        case .capabilityUnavailable(let capability, let tier):
            "no model for capability \(capability.rawValue) on hardware tier \(tier.rawValue)"
        case .modelPackUnverified(let reason): "model pack failed verification: \(reason)"
        case .modelPackNotFound(let capability): "no model pack registered for \(capability.rawValue)"
        case .requestCancelled: "request cancelled (preempted by an interactive request)"
        case .memoryCapExceeded: "memory governor cap exceeded"
        case .adapterFailure(let reason): "adapter failure: \(reason)"
        }
    }

    public var recoverability: InferenceErrorRecoverability {
        switch self {
        case .capabilityUnavailable, .modelPackNotFound: .userAction
        case .modelPackUnverified: .fatal
        case .requestCancelled: .retryable
        case .memoryCapExceeded: .retryable
        case .adapterFailure: .retryable
        }
    }
}
