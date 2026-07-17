import Foundation
import PDFEngineAPI

/// Typed failure taxonomy for `DocumentSession` (CLAUDE.md §15 shape).
public enum DocumentSessionError: Error, Sendable, Equatable {
    case alreadyOpen
    case notOpen
    case engine(PDFEngineError)

    public var userMessageKey: String {
        switch self {
        case .alreadyOpen: "error.documentSession.alreadyOpen"
        case .notOpen: "error.documentSession.notOpen"
        case .engine(let underlying): underlying.userMessageKey
        }
    }

    public var recoverability: PDFEngineErrorRecoverability {
        switch self {
        case .alreadyOpen, .notOpen: .userAction
        case .engine(let underlying): underlying.recoverability
        }
    }
}

/// Owns one open document's lifecycle for the app: open -> hold the engine
/// handle -> serve page metadata/tiles -> close. This is the P0-07 "v1"
/// scope (root CLAUDE.md driver 5 substrate) — undo, annotation, and
/// form-fill state land in later viewer/forms tasks (P1-01+).
///
/// Depends only on `PDFEngineAPI` protocols, never a concrete engine
/// (`DocEngineHost` is Infrastructure) — the composition root (`App/`)
/// injects the real `PDFiumEngine` or, in tests, `FakePDFEngine`.
public actor DocumentSession {
    private let lifecycle: any DocumentLifecycle
    private let renderer: any PageRenderer
    private let outlineReader: (any OutlineReader)?
    private var handle: DocumentHandle?

    public init(lifecycle: any DocumentLifecycle, renderer: any PageRenderer, outlineReader: (any OutlineReader)? = nil) {
        self.lifecycle = lifecycle
        self.renderer = renderer
        self.outlineReader = outlineReader
    }

    public var isOpen: Bool { handle != nil }

    /// Opens `url` through the engine. Every failure the engine can throw
    /// (corrupt file, unsupported feature, I/O) is translated into a typed
    /// `DocumentSessionError`, never a crash — CLAUDE.md §15's "total"
    /// requirement for user-input-reachable paths.
    public func open(url: URL) async throws {
        guard handle == nil else { throw DocumentSessionError.alreadyOpen }
        do {
            handle = try await lifecycle.open(url: url)
        } catch let error as PDFEngineError {
            throw DocumentSessionError.engine(error)
        }
    }

    public func close() async throws {
        guard let handle else { throw DocumentSessionError.notOpen }
        do {
            try await lifecycle.close(handle)
        } catch let error as PDFEngineError {
            throw DocumentSessionError.engine(error)
        }
        self.handle = nil
    }

    public func pageCount() async throws -> Int {
        try await renderer.pageCount(of: openHandle())
    }

    public func metadata(page: PageIndex) async throws -> PageMetadata {
        try await renderer.metadata(of: openHandle(), page: page)
    }

    public func renderTile(_ request: TileRenderRequest) async throws -> RenderedTile {
        try await renderer.renderTile(of: openHandle(), request: request)
    }

    /// Empty when no `outlineReader` was wired (e.g. tests built against
    /// `FakePDFEngine` alone) or the document has no outline — both are
    /// normal, not errors.
    public func outline() async throws -> [OutlineNode] {
        guard let outlineReader else { return [] }
        return try await outlineReader.outline(of: openHandle())
    }

    private func openHandle() throws -> DocumentHandle {
        guard let handle else { throw DocumentSessionError.notOpen }
        return handle
    }
}
