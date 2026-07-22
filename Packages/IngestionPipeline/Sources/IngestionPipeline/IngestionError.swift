import Foundation

/// Typed error taxonomy for this module (CLAUDE.md §15 shape: user-presentable
/// message key, debug description, recoverability class). Self-contained, no
/// dependency on a shared error protocol — same pattern `PDFEngineError` uses,
/// since this package's import allowlist is narrow (Foundation/PDFEngineAPI/
/// VaultAPI/InferenceAPI only).
public enum IngestionError: Error, Sendable, Equatable {
    case unsupportedFormat(DocumentFormat)
    case corruptInput(DocumentFormat, reason: String)
    case sizeLimitExceeded(bytes: Int, limit: Int)
    case classificationUnavailable
    case cancelled
    case engine(String)

    public var userMessageKey: String {
        switch self {
        case .unsupportedFormat: "error.ingestion.unsupportedFormat"
        case .corruptInput: "error.ingestion.corruptInput"
        case .sizeLimitExceeded: "error.ingestion.sizeLimitExceeded"
        case .classificationUnavailable: "error.ingestion.classificationUnavailable"
        case .cancelled: "error.ingestion.cancelled"
        case .engine: "error.ingestion.engine"
        }
    }

    /// Debug-only description — never includes document content, only
    /// counts/format identifiers/enum states (CLAUDE.md §16).
    public var debugDescription: String {
        switch self {
        case .unsupportedFormat(let format): "unsupported format: \(format)"
        case .corruptInput(let format, let reason): "corrupt \(format) input: \(reason)"
        case .sizeLimitExceeded(let bytes, let limit): "input size \(bytes) exceeds limit \(limit)"
        case .classificationUnavailable: "classification endpoint unavailable"
        case .cancelled: "ingestion cancelled"
        case .engine(let reason): "engine error: \(reason)"
        }
    }

    public var recoverability: IngestionRecoverability {
        switch self {
        case .unsupportedFormat, .corruptInput:
            .userAction
        case .sizeLimitExceeded:
            .userAction
        case .classificationUnavailable:
            .retryable
        case .cancelled:
            .retryable
        case .engine:
            .retryable
        }
    }
}

public enum IngestionRecoverability: String, Sendable, Equatable {
    case retryable
    case userAction
    case fatal
}
