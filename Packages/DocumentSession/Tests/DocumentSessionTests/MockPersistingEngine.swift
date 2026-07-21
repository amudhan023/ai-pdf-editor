import Foundation
import PDFEngineAPI

/// Test-local double (`Mock*`, not the shipped `Fake*`) that genuinely
/// round-trips annotation state through disk bytes on `save`/`open`, unlike
/// `FakePDFEngine`'s in-memory-only no-ops. Exists solely to prove
/// `DocumentSession.save()`'s wiring end-to-end (open -> mutate -> save ->
/// reopen -> read back) within this package's import allowlist: real
/// `PDFiumEngine` lives in `DocEngineHost`, which `DocumentSession` may
/// never import (composition-root-only concrete engine, see `App/CLAUDE.md`)
/// — that boundary is why this test double exists rather than using the
/// real engine here. `DocEngineHost`'s own P1-21 tests already cover the
/// real-PDFium open->mutate->save->reopen round trip at the engine layer.
actor MockPersistingEngine: DocumentLifecycle, PageRenderer, AnnotationStore {
    struct PersistedState: Codable {
        var pageCount: Int
        var annotations: [Annotation]
    }

    private var openDocuments: [DocumentHandle: PersistedState] = [:]

    /// Seeds `url` with a valid empty document before a test's first `open`,
    /// mimicking a pre-existing fixture file.
    static func writeInitialDocument(at url: URL, pageCount: Int = 1) throws {
        let state = PersistedState(pageCount: pageCount, annotations: [])
        try JSONEncoder().encode(state).write(to: url)
    }

    func open(url: URL) async throws -> DocumentHandle {
        let handle = DocumentHandle()
        if let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            openDocuments[handle] = state
        } else {
            openDocuments[handle] = PersistedState(pageCount: 1, annotations: [])
        }
        return handle
    }

    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {
        guard let state = openDocuments[document] else { throw PDFEngineError.documentNotFound(document) }
        try JSONEncoder().encode(state).write(to: url)
    }

    func close(_ document: DocumentHandle) async throws {
        openDocuments.removeValue(forKey: document)
    }

    func pageCount(of document: DocumentHandle) async throws -> Int {
        try state(for: document).pageCount
    }

    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        let state = try state(for: document)
        guard page.value < state.pageCount else {
            throw PDFEngineError.pageIndexOutOfRange(index: page.value, pageCount: state.pageCount)
        }
        return PageMetadata(index: page, size: PageSize(width: 612, height: 792), rotation: .none)
    }

    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        _ = try state(for: document)
        return RenderedTile(request: request, pixelWidth: 1, pixelHeight: 1, pixelData: Data(count: 4))
    }

    func annotations(of document: DocumentHandle, page: PageIndex) async throws -> [Annotation] {
        try state(for: document).annotations.filter { $0.page == page }
    }

    func add(_ annotation: Annotation, to document: DocumentHandle) async throws {
        var state = try state(for: document)
        state.annotations.append(annotation)
        openDocuments[document] = state
    }

    func update(_ annotation: Annotation, in document: DocumentHandle) async throws {
        var state = try state(for: document)
        guard let index = state.annotations.firstIndex(where: { $0.id == annotation.id }) else {
            throw PDFEngineError.fieldNotFound(annotation.id.uuidString)
        }
        state.annotations[index] = annotation
        openDocuments[document] = state
    }

    func remove(_ id: Annotation.ID, from document: DocumentHandle) async throws {
        var state = try state(for: document)
        state.annotations.removeAll { $0.id == id }
        openDocuments[document] = state
    }

    private func state(for document: DocumentHandle) throws -> PersistedState {
        guard let state = openDocuments[document] else { throw PDFEngineError.documentNotFound(document) }
        return state
    }
}
