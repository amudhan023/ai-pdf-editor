import Foundation

/// In-memory implementation of every protocol in this package, for use in
/// consumers' tests (CLAUDE.md §5's `Fake*` naming: shipped in the API
/// package, not a test-local `Mock*`). Backs nothing to disk; `open` always
/// synthesizes a single default US-Letter page rather than parsing `url`.
public actor FakePDFEngine: PageRenderer, TextEditor, PageOrganizer, AnnotationStore, FormModel, DocumentLifecycle {
    private struct State {
        var pages: [PageMetadata]
        var textRuns: [TextRun]
        var annotations: [Annotation]
        var fields: [String: FormField]
    }

    private var documents: [DocumentHandle: State] = [:]

    public init() {}

    private func state(for document: DocumentHandle) throws -> State {
        guard let state = documents[document] else { throw PDFEngineError.documentNotFound(document) }
        return state
    }

    // MARK: - Test seeding (not part of any protocol — fake-only conveniences)

    @discardableResult
    public func seedDocument(pageCount: Int = 1, pageSize: PageSize = PageSize(width: 612, height: 792)) -> DocumentHandle {
        let handle = DocumentHandle()
        let pages = (0..<pageCount).map { PageMetadata(index: PageIndex($0), size: pageSize, rotation: .none) }
        documents[handle] = State(pages: pages, textRuns: [], annotations: [], fields: [:])
        return handle
    }

    public func seedFields(_ fields: [FormField], for document: DocumentHandle) throws {
        var state = try state(for: document)
        for field in fields { state.fields[field.id] = field }
        documents[document] = state
    }

    public func seedTextRuns(_ runs: [TextRun], for document: DocumentHandle) throws {
        var state = try state(for: document)
        state.textRuns.append(contentsOf: runs)
        documents[document] = state
    }

    // MARK: - DocumentLifecycle

    public func open(url: URL) async throws -> DocumentHandle {
        seedDocument()
    }

    public func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {
        _ = try state(for: document)
    }

    public func close(_ document: DocumentHandle) async throws {
        _ = try state(for: document)
        documents.removeValue(forKey: document)
    }

    // MARK: - PageRenderer

    public func pageCount(of document: DocumentHandle) async throws -> Int {
        try state(for: document).pages.count
    }

    public func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        let state = try state(for: document)
        guard page.value >= 0, page.value < state.pages.count else {
            throw PDFEngineError.pageIndexOutOfRange(index: page.value, pageCount: state.pages.count)
        }
        return state.pages[page.value]
    }

    public func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        _ = try await metadata(of: document, page: request.page)
        let width = max(1, Int(request.tileRect.width * request.scale))
        let height = max(1, Int(request.tileRect.height * request.scale))
        return RenderedTile(request: request, pixelWidth: width, pixelHeight: height, pixelData: Data(count: width * height * 4))
    }

    // MARK: - TextEditor

    public func textRuns(of document: DocumentHandle, page: PageIndex) async throws -> [TextRun] {
        try state(for: document).textRuns.filter { $0.page == page }
    }

    public func replaceText(of document: DocumentHandle, run: TextRun.ID, with newText: String) async throws {
        var state = try state(for: document)
        guard let index = state.textRuns.firstIndex(where: { $0.id == run }) else {
            throw PDFEngineError.fieldNotFound(run.uuidString)
        }
        let old = state.textRuns[index]
        state.textRuns[index] = TextRun(id: old.id, page: old.page, text: newText, boundingBox: old.boundingBox, fontSize: old.fontSize)
        documents[document] = state
    }

    // MARK: - PageOrganizer

    public func apply(_ operation: PageOperation, to document: DocumentHandle) async throws {
        var state = try state(for: document)
        switch operation {
        case .insert(let source, let sourcePage, let at):
            let sourceState = try self.state(for: source)
            guard sourcePage.value >= 0, sourcePage.value < sourceState.pages.count else {
                throw PDFEngineError.pageIndexOutOfRange(index: sourcePage.value, pageCount: sourceState.pages.count)
            }
            let insertAt = min(max(0, at.value), state.pages.count)
            state.pages.insert(sourceState.pages[sourcePage.value], at: insertAt)
            state.pages = reindexed(state.pages)

        case .delete(let page):
            guard page.value >= 0, page.value < state.pages.count else {
                throw PDFEngineError.pageIndexOutOfRange(index: page.value, pageCount: state.pages.count)
            }
            state.pages.remove(at: page.value)
            state.pages = reindexed(state.pages)

        case .reorder(let from, let to):
            guard from.value >= 0, from.value < state.pages.count else {
                throw PDFEngineError.pageIndexOutOfRange(index: from.value, pageCount: state.pages.count)
            }
            let page = state.pages.remove(at: from.value)
            let insertAt = min(max(0, to.value), state.pages.count)
            state.pages.insert(page, at: insertAt)
            state.pages = reindexed(state.pages)

        case .rotate(let page, let rotation):
            guard page.value >= 0, page.value < state.pages.count else {
                throw PDFEngineError.pageIndexOutOfRange(index: page.value, pageCount: state.pages.count)
            }
            let existing = state.pages[page.value]
            state.pages[page.value] = PageMetadata(index: existing.index, size: existing.size, rotation: rotation)
        }
        documents[document] = state
    }

    private func reindexed(_ pages: [PageMetadata]) -> [PageMetadata] {
        pages.enumerated().map { offset, page in
            PageMetadata(index: PageIndex(offset), size: page.size, rotation: page.rotation)
        }
    }

    // MARK: - AnnotationStore

    public func annotations(of document: DocumentHandle, page: PageIndex) async throws -> [Annotation] {
        try state(for: document).annotations.filter { $0.page == page }
    }

    public func add(_ annotation: Annotation, to document: DocumentHandle) async throws {
        var state = try state(for: document)
        state.annotations.append(annotation)
        documents[document] = state
    }

    public func update(_ annotation: Annotation, in document: DocumentHandle) async throws {
        var state = try state(for: document)
        guard let index = state.annotations.firstIndex(where: { $0.id == annotation.id }) else {
            throw PDFEngineError.fieldNotFound(annotation.id.uuidString)
        }
        state.annotations[index] = annotation
        documents[document] = state
    }

    public func remove(_ id: Annotation.ID, from document: DocumentHandle) async throws {
        var state = try state(for: document)
        guard let index = state.annotations.firstIndex(where: { $0.id == id }) else {
            throw PDFEngineError.fieldNotFound(id.uuidString)
        }
        state.annotations.remove(at: index)
        documents[document] = state
    }

    // MARK: - FormModel

    public func fields(of document: DocumentHandle) async throws -> [FormField] {
        Array(try state(for: document).fields.values).sorted { $0.tabOrder < $1.tabOrder }
    }

    public func setValue(_ value: String?, for fieldID: FormField.ID, in document: DocumentHandle) async throws {
        var state = try state(for: document)
        guard let field = state.fields[fieldID] else { throw PDFEngineError.fieldNotFound(fieldID) }
        state.fields[fieldID] = FormField(
            name: field.name,
            page: field.page,
            rect: field.rect,
            kind: field.kind,
            formatHint: field.formatHint,
            tooltip: field.tooltip,
            tabOrder: field.tabOrder,
            isReadOnly: field.isReadOnly,
            currentValue: value
        )
        documents[document] = state
    }
}
