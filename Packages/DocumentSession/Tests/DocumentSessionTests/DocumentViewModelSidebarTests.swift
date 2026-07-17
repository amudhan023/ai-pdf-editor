import XCTest
import PDFEngineAPI
@testable import DocumentSession

@MainActor
final class DocumentViewModelSidebarTests: XCTestCase {
    func testOpenLoadsTheDocumentOutline() async {
        let engine = FakePDFEngine()
        let reader = MockOutlineReader(outline: [
            OutlineNode(title: "Chapter 1", destinationPage: PageIndex(0), children: [
                OutlineNode(title: "Section 1.1", destinationPage: PageIndex(2), zoom: 1.5)
            ])
        ])
        let session = DocumentSession(lifecycle: engine, renderer: engine, outlineReader: reader)
        let viewModel = DocumentViewModel(session: session)

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/outlined.pdf"))

        XCTAssertEqual(viewModel.outline.count, 1)
        XCTAssertEqual(viewModel.outline.first?.children.first?.title, "Section 1.1")
    }

    func testOutlineIsEmptyWhenNoReaderIsWired() async {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let viewModel = DocumentViewModel(session: session)

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/plain.pdf"))

        XCTAssertEqual(viewModel.state, .loaded(pageCount: 1))
        XCTAssertTrue(viewModel.outline.isEmpty)
    }

    func testFailedOutlineReadDegradesToEmptyWithoutFailingTheOpen() async {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine, outlineReader: MockOutlineReader(error: PDFEngineError.ioFailure("corrupt outline")))
        let viewModel = DocumentViewModel(session: session)

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/bad-outline.pdf"))

        XCTAssertEqual(viewModel.state, .loaded(pageCount: 1))
        XCTAssertTrue(viewModel.outline.isEmpty)
    }

    func testNavigateSetsTargetAndAppliesZoom() async {
        let viewModel = await openedViewModel()

        viewModel.navigate(to: PageIndex(7), zoom: 2.0)

        XCTAssertEqual(viewModel.navigationTarget?.page, PageIndex(7))
        XCTAssertEqual(viewModel.zoomMode, .custom(2.0))
    }

    func testNavigateWithoutZoomLeavesZoomModeAlone() async {
        let viewModel = await openedViewModel()
        viewModel.setZoomMode(.fitPage)

        viewModel.navigate(to: PageIndex(3))

        XCTAssertEqual(viewModel.navigationTarget?.page, PageIndex(3))
        XCTAssertEqual(viewModel.zoomMode, .fitPage)
    }

    func testRepeatNavigationToTheSamePageProducesADistinctTarget() async {
        let viewModel = await openedViewModel()

        viewModel.navigate(to: PageIndex(3))
        let first = viewModel.navigationTarget
        viewModel.navigate(to: PageIndex(3))

        XCTAssertNotEqual(first, viewModel.navigationTarget, "onChange-driven scrolling needs a fresh value per click, even for the same page")
    }

    func testPageDidBecomeVisibleTracksCurrentPageAndPersistsScroll() async {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let store = FakeScrollPositionStore()
        let url = URL(fileURLWithPath: "/tmp/tracked.pdf")
        let viewModel = DocumentViewModel(session: session, scrollStore: store)
        await viewModel.open(url: url)

        viewModel.pageDidBecomeVisible(PageIndex(6))

        XCTAssertEqual(viewModel.currentPage, PageIndex(6))
        XCTAssertEqual(store.position(for: url), ScrollPosition(page: 6, verticalFraction: 0))
    }

    func testReopeningResetsSidebarState() async {
        let viewModel = await openedViewModel()
        viewModel.thumbnailSelection.select(PageIndex(2))
        viewModel.pageDidBecomeVisible(PageIndex(2))
        viewModel.navigate(to: PageIndex(2))

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/second.pdf"))

        XCTAssertTrue(viewModel.thumbnailSelection.selectedPages.isEmpty)
        XCTAssertNil(viewModel.currentPage)
        XCTAssertNil(viewModel.navigationTarget)
    }

    /// P1-02 acceptance: a 1,000-page document must open without any
    /// eager per-page work. Thumbnails and tiles are pull-based (each
    /// materialized row fetches its own), so open itself performs zero
    /// renders and zero per-page metadata reads regardless of page count —
    /// that, plus `LazyVStack` row laziness and `TileCache`'s byte budget,
    /// is the virtualization contract.
    func testOpeningAThousandPageDocumentDoesNoEagerPerPageWork() async {
        let engine = FakePDFEngine()
        let seeded = await engine.seedDocument(pageCount: 1000)
        let lifecycle = MockSeededLifecycle(engine: engine, handle: seeded)
        let counting = CountingEngineProxy(wrapping: engine)
        let session = DocumentSession(lifecycle: lifecycle, renderer: counting)
        let viewModel = DocumentViewModel(session: session)

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/thousand.pdf"))

        XCTAssertEqual(viewModel.state, .loaded(pageCount: 1000))
        let renders = await counting.renderCount
        let metadataReads = await counting.metadataCount
        XCTAssertEqual(renders, 0, "open must not render any page eagerly")
        XCTAssertEqual(metadataReads, 0, "open must not touch per-page metadata eagerly")
    }

    private func openedViewModel() async -> DocumentViewModel {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let viewModel = DocumentViewModel(session: session)
        await viewModel.open(url: URL(fileURLWithPath: "/tmp/doc.pdf"))
        return viewModel
    }
}

/// Test-local `Mock*` (CLAUDE.md §5): fixed outline or fixed failure,
/// independent of which handle the session opened.
private struct MockOutlineReader: OutlineReader {
    var outline: [OutlineNode] = []
    var error: PDFEngineError?

    func outline(of document: DocumentHandle) async throws -> [OutlineNode] {
        if let error { throw error }
        return outline
    }
}

/// `FakePDFEngine.open` always synthesizes a 1-page document; this lifecycle
/// hands back a pre-seeded (e.g. 1,000-page) handle instead.
private struct MockSeededLifecycle: DocumentLifecycle {
    let engine: FakePDFEngine
    let handle: DocumentHandle

    func open(url: URL) async throws -> DocumentHandle { handle }
    func close(_ document: DocumentHandle) async throws { try await engine.close(document) }
    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {
        try await engine.save(document, mode: mode, to: url)
    }
}

/// Counts render + per-page metadata calls so tests can assert "no eager
/// per-page work" without reaching into cache internals.
private actor CountingEngineProxy: PageRenderer {
    private let wrapped: FakePDFEngine
    private(set) var renderCount = 0
    private(set) var metadataCount = 0

    init(wrapping wrapped: FakePDFEngine) {
        self.wrapped = wrapped
    }

    func pageCount(of document: DocumentHandle) async throws -> Int {
        try await wrapped.pageCount(of: document)
    }

    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        metadataCount += 1
        return try await wrapped.metadata(of: document, page: page)
    }

    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        renderCount += 1
        return try await wrapped.renderTile(of: document, request: request)
    }
}
