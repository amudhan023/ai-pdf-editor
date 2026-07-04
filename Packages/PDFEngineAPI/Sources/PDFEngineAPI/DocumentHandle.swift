import Foundation

/// Opaque reference to a document open in some `DocumentLifecycle` implementation.
/// Never carries document content itself — just an identity for subsequent calls.
public struct DocumentHandle: Sendable, Hashable, Codable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// How badly a `PDFEngineError` should be treated by a caller (CLAUDE.md §15 shape).
public enum PDFEngineErrorRecoverability: String, Sendable, Codable {
    case retryable
    case userAction
    case fatal
}

/// Typed error taxonomy for this module. Self-contained (no dependency on a
/// shared error protocol, since PDFEngineAPI's import allowlist is Foundation-only) —
/// conforms to the shape CLAUDE.md §15 asks of every module's errors: a
/// user-presentable message key, a debug description, and a recoverability class.
public enum PDFEngineError: Error, Sendable, Codable, Equatable {
    case documentNotFound(DocumentHandle)
    case corruptDocument(reason: String)
    case unsupportedFeature(String)
    case pageIndexOutOfRange(index: Int, pageCount: Int)
    case fieldNotFound(String)
    case ioFailure(String)
    case saveConflict
    case cancelled

    public var userMessageKey: String {
        switch self {
        case .documentNotFound: "error.pdfEngine.documentNotFound"
        case .corruptDocument: "error.pdfEngine.corruptDocument"
        case .unsupportedFeature: "error.pdfEngine.unsupportedFeature"
        case .pageIndexOutOfRange: "error.pdfEngine.pageIndexOutOfRange"
        case .fieldNotFound: "error.pdfEngine.fieldNotFound"
        case .ioFailure: "error.pdfEngine.ioFailure"
        case .saveConflict: "error.pdfEngine.saveConflict"
        case .cancelled: "error.pdfEngine.cancelled"
        }
    }

    public var debugDescription: String {
        switch self {
        case .documentNotFound(let handle): "document not found: \(handle.id)"
        case .corruptDocument(let reason): "corrupt document: \(reason)"
        case .unsupportedFeature(let feature): "unsupported feature: \(feature)"
        case .pageIndexOutOfRange(let index, let count): "page index \(index) out of range (0..<\(count))"
        case .fieldNotFound(let name): "form field not found: \(name)"
        case .ioFailure(let reason): "I/O failure: \(reason)"
        case .saveConflict: "save conflict: document changed since last read"
        case .cancelled: "operation cancelled"
        }
    }

    public var recoverability: PDFEngineErrorRecoverability {
        switch self {
        case .documentNotFound, .corruptDocument, .unsupportedFeature, .pageIndexOutOfRange, .fieldNotFound:
            .userAction
        case .ioFailure, .saveConflict, .cancelled:
            .retryable
        }
    }
}
