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
    private let textEditor: (any TextEditor)?
    private let annotationStore: (any AnnotationStore)?
    private var handle: DocumentHandle?
    private var annotationUndo = AnnotationUndoStack()

    public init(
        lifecycle: any DocumentLifecycle,
        renderer: any PageRenderer,
        outlineReader: (any OutlineReader)? = nil,
        textEditor: (any TextEditor)? = nil,
        annotationStore: (any AnnotationStore)? = nil
    ) {
        self.lifecycle = lifecycle
        self.renderer = renderer
        self.outlineReader = outlineReader
        self.textEditor = textEditor
        self.annotationStore = annotationStore
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

    /// Empty when no `textEditor` was wired — same degradation contract as
    /// `outline()`: search over such a session finds nothing rather than
    /// erroring, and tests that don't care about text stay unaffected.
    public func textRuns(page: PageIndex) async throws -> [TextRun] {
        guard let textEditor else { return [] }
        return try await textEditor.textRuns(of: openHandle(), page: page)
    }

    private func openHandle() throws -> DocumentHandle {
        guard let handle else { throw DocumentSessionError.notOpen }
        return handle
    }

    // MARK: - Annotations (P1-04)

    /// Empty when no `annotationStore` was wired — same degradation
    /// contract as `outline()`/`textRuns()`.
    public func annotations(page: PageIndex) async throws -> [Annotation] {
        guard let annotationStore else { return [] }
        return try await annotationStore.annotations(of: openHandle(), page: page)
    }

    public var canUndoAnnotation: Bool { annotationUndo.canUndo }
    public var canRedoAnnotation: Bool { annotationUndo.canRedo }

    public func addAnnotation(_ annotation: Annotation) async throws {
        let store = try requireAnnotationStore()
        try await store.add(annotation, to: openHandle())
        annotationUndo.record(.added(annotation))
    }

    public func updateAnnotation(_ annotation: Annotation) async throws {
        let store = try requireAnnotationStore()
        let handle = try openHandle()
        let before = try await store.annotations(of: handle, page: annotation.page)
            .first(where: { $0.id == annotation.id })
        try await store.update(annotation, in: handle)
        if let before {
            annotationUndo.record(.updated(before: before, after: annotation))
        }
    }

    public func removeAnnotation(_ id: Annotation.ID, page: PageIndex) async throws {
        let store = try requireAnnotationStore()
        let handle = try openHandle()
        guard let existing = try await store.annotations(of: handle, page: page).first(where: { $0.id == id }) else {
            throw DocumentSessionError.engine(.fieldNotFound(id.uuidString))
        }
        try await store.remove(id, from: handle)
        annotationUndo.record(.removed(existing))
    }

    @discardableResult
    public func undoAnnotation() async throws -> Bool {
        guard let change = annotationUndo.undo() else { return false }
        try await apply(change)
        return true
    }

    @discardableResult
    public func redoAnnotation() async throws -> Bool {
        guard let change = annotationUndo.redo() else { return false }
        try await apply(change)
        return true
    }

    private func apply(_ change: AnnotationUndoStack.Change) async throws {
        let store = try requireAnnotationStore()
        let handle = try openHandle()
        switch change {
        case .added(let annotation):
            try await store.add(annotation, to: handle)
        case .removed(let annotation):
            try await store.remove(annotation.id, from: handle)
        case .updated(_, let after):
            try await store.update(after, in: handle)
        }
    }

    private func requireAnnotationStore() throws -> any AnnotationStore {
        guard let annotationStore else { throw DocumentSessionError.engine(.unsupportedFeature("annotationsNotWired")) }
        return annotationStore
    }
}
