import Foundation
import PDFEngineAPI

/// Typed failure taxonomy for `DocumentSession` (CLAUDE.md §15 shape).
public enum DocumentSessionError: Error, Sendable, Equatable {
    case alreadyOpen
    case notOpen
    case engine(PDFEngineError)
    case saveFailed(AtomicSaveError)

    public var userMessageKey: String {
        switch self {
        case .alreadyOpen: "error.documentSession.alreadyOpen"
        case .notOpen: "error.documentSession.notOpen"
        case .engine(let underlying): underlying.userMessageKey
        case .saveFailed: "error.documentSession.saveFailed"
        }
    }

    public var recoverability: PDFEngineErrorRecoverability {
        switch self {
        case .alreadyOpen, .notOpen: .userAction
        case .engine(let underlying): underlying.recoverability
        case .saveFailed: .retryable
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
    private let pageOrganizer: (any PageOrganizer)?
    private let atomicSaver: AtomicSaver?
    private var handle: DocumentHandle?
    private var currentURL: URL?
    private var annotationUndo = AnnotationUndoStack()
    private var pageOperationUndo = PageOperationUndoStack()
    /// Handles opened by `insertPage(fromFile:...)`/`mergeDocument(fromFile:)`,
    /// kept alive so a later `redo()` can still reference them — see those
    /// methods' doc comments. Closed alongside the main document in `close()`.
    private var importSourceHandles: [DocumentHandle] = []

    public init(
        lifecycle: any DocumentLifecycle,
        renderer: any PageRenderer,
        outlineReader: (any OutlineReader)? = nil,
        textEditor: (any TextEditor)? = nil,
        annotationStore: (any AnnotationStore)? = nil,
        pageOrganizer: (any PageOrganizer)? = nil,
        atomicSaver: AtomicSaver? = nil
    ) {
        self.lifecycle = lifecycle
        self.renderer = renderer
        self.outlineReader = outlineReader
        self.textEditor = textEditor
        self.annotationStore = annotationStore
        self.pageOrganizer = pageOrganizer
        self.atomicSaver = atomicSaver
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
            currentURL = url
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
        currentURL = nil
        for source in importSourceHandles { try? await lifecycle.close(source) }
        importSourceHandles.removeAll()
    }

    /// Serializes the open document's current (mutated) state through the
    /// engine, then commits it via the never-corrupt atomic-save path
    /// (`AtomicSaver`): the engine writes to a same-directory sibling temp
    /// file (same volume, so the replace below is a true atomic rename —
    /// never system `/tmp`, and the file only exists transiently for the
    /// duration of this call), which `AtomicSaver` then validates and swaps
    /// into place. `PDFEngineError` from the engine surfaces as
    /// `.engine(...)`; a failure in the atomic-replace step itself surfaces
    /// as `.saveFailed(...)` — neither is swallowed or generalized (CLAUDE.md §15).
    public func save(mode: SaveMode = .incremental) async throws {
        guard let currentURL else { throw DocumentSessionError.notOpen }
        let handle = try openHandle()
        guard let atomicSaver else {
            throw DocumentSessionError.engine(.unsupportedFeature("atomicSaverNotWired"))
        }
        let tempURL = currentURL.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)-\(currentURL.lastPathComponent)")
        do {
            try await lifecycle.save(handle, mode: mode, to: tempURL)
        } catch let error as PDFEngineError {
            try? FileManager.default.removeItem(at: tempURL)
            throw DocumentSessionError.engine(error)
        }
        do {
            try await atomicSaver.replace(original: currentURL, withTemp: tempURL)
        } catch let error as AtomicSaveError {
            try? FileManager.default.removeItem(at: tempURL)
            throw DocumentSessionError.saveFailed(error)
        }
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

    // MARK: - Page management (P1-06)

    public var canUndoPageOperation: Bool { pageOperationUndo.canUndo }
    public var canRedoPageOperation: Bool { pageOperationUndo.canRedo }

    /// Moves the page at `from` to `to` (same clamping convention as
    /// `PageOrganizer.apply(.reorder)`: `to` is an index into the array
    /// *after* the moved page is removed). Undoable.
    public func reorderPage(from: PageIndex, to: PageIndex) async throws {
        let organizer = try requirePageOrganizer()
        try await organizer.apply(.reorder(from: from, to: to), to: openHandle())
        pageOperationUndo.record(.reordered(from: from, to: to))
    }

    /// Undoable.
    public func rotatePage(_ page: PageIndex, by rotation: PageRotation) async throws {
        let organizer = try requirePageOrganizer()
        let previous = try await renderer.metadata(of: openHandle(), page: page).rotation
        try await organizer.apply(.rotate(page, by: rotation), to: openHandle())
        pageOperationUndo.record(.rotated(page, from: previous, to: rotation))
    }

    /// Duplicates the currently open document's own page `sourcePage`,
    /// inserting the copy at `at`. Undoable.
    public func duplicatePage(_ sourcePage: PageIndex, at: PageIndex) async throws {
        let organizer = try requirePageOrganizer()
        let handle = try openHandle()
        try await organizer.apply(.insert(from: handle, sourcePage: sourcePage, at: at), to: handle)
        pageOperationUndo.record(.inserted(from: handle, sourcePage: sourcePage, at: at))
    }

    /// Imports one page from an external file (not the currently open
    /// document) at `at` — the "insert from file" flow. Opens `fileURL`
    /// through the same engine instance and keeps that handle open for the
    /// rest of this session (closed in `close()`, alongside the main
    /// document) rather than closing it right after the import: the
    /// recorded undo `Change` references the source `DocumentHandle`
    /// directly, and `redo()` re-runs the same `.insert` against it — a
    /// closed handle would make redo fail with `.documentNotFound`.
    /// Undoable.
    public func insertPage(fromFile fileURL: URL, sourcePage: PageIndex, at: PageIndex) async throws {
        let organizer = try requirePageOrganizer()
        let handle = try openHandle()
        let source = try await openImportSource(fileURL)
        try await organizer.apply(.insert(from: source, sourcePage: sourcePage, at: at), to: handle)
        pageOperationUndo.record(.inserted(from: source, sourcePage: sourcePage, at: at))
    }

    /// Appends every page of `fileURL` to the end of the currently open
    /// document, in source order — the "merge" composition, built entirely
    /// from repeated `.insert` (no dedicated engine op needed, matching
    /// `PageOrganizer.swift`'s own doc comment on how merge/duplicate/
    /// extract compose). Each imported page is individually undoable via
    /// the same `undoPageOperation()` this method's siblings use; there is
    /// no single combined "undo the whole merge" step — undoing N times
    /// undoes N imports, in reverse order, same as any other multi-step
    /// action on this stack. Same source-handle-stays-open rationale as
    /// `insertPage(fromFile:sourcePage:at:)`.
    public func mergeDocument(fromFile fileURL: URL) async throws {
        let organizer = try requirePageOrganizer()
        let handle = try openHandle()
        let source = try await openImportSource(fileURL)

        let sourcePageCount: Int
        do {
            sourcePageCount = try await renderer.pageCount(of: source)
        } catch let error as PDFEngineError {
            throw DocumentSessionError.engine(error)
        }
        for i in 0..<sourcePageCount {
            let destCount = try await renderer.pageCount(of: handle)
            let operation = PageOperation.insert(from: source, sourcePage: PageIndex(i), at: PageIndex(destCount))
            try await organizer.apply(operation, to: handle)
            pageOperationUndo.record(.inserted(from: source, sourcePage: PageIndex(i), at: PageIndex(destCount)))
        }
    }

    /// Opens `fileURL` as an import source and tracks the handle for
    /// cleanup in `close()`. Every call opens a fresh handle (even for a
    /// repeated `fileURL`) rather than caching by URL — simpler, and this
    /// package never learns whether the file changed between calls.
    private func openImportSource(_ fileURL: URL) async throws -> DocumentHandle {
        do {
            let source = try await lifecycle.open(url: fileURL)
            importSourceHandles.append(source)
            return source
        } catch let error as PDFEngineError {
            throw DocumentSessionError.engine(error)
        }
    }

    /// Deletes `page`. **Not undoable in this version** — see
    /// `PageOperationUndoStack`'s doc comment for why (no capability
    /// reachable from this package creates the "trash" document a real
    /// content-preserving delete-undo would need). Callers should surface
    /// a destructive-action confirmation before calling this, same as any
    /// non-undoable delete. Also clears any existing undo/redo history:
    /// a delete shifts every later page's index, which can silently
    /// invalidate an already-recorded operation's indices (see
    /// `PageOperationUndoStack.invalidateHistory()`).
    public func deletePage(_ page: PageIndex) async throws {
        let organizer = try requirePageOrganizer()
        try await organizer.apply(.delete(page), to: openHandle())
        pageOperationUndo.invalidateHistory()
    }

    @discardableResult
    public func undoPageOperation() async throws -> Bool {
        guard let operation = pageOperationUndo.undo() else { return false }
        try await requirePageOrganizer().apply(operation, to: openHandle())
        return true
    }

    @discardableResult
    public func redoPageOperation() async throws -> Bool {
        guard let operation = pageOperationUndo.redo() else { return false }
        try await requirePageOrganizer().apply(operation, to: openHandle())
        return true
    }

    private func requirePageOrganizer() throws -> any PageOrganizer {
        guard let pageOrganizer else { throw DocumentSessionError.engine(.unsupportedFeature("pageOrganizerNotWired")) }
        return pageOrganizer
    }
}
