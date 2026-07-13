import XCTest
import PDFEngineAPI
@testable import DocumentSession

@MainActor
final class DocumentViewModelTileTests: XCTestCase {
    func testTileIsServedFromCacheOnASecondRequestWithoutRenderingAgain() async throws {
        let engine = FakePDFEngine()
        let counting = CountingRenderer(wrapping: engine)
        let session = DocumentSession(lifecycle: engine, renderer: counting)
        let viewModel = DocumentViewModel(session: session)
        await viewModel.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))

        let rect = PDFRect(x: 0, y: 0, width: 200, height: 200)
        let first = await viewModel.tile(page: PageIndex(0), tileRect: rect, scale: 1.0)
        let second = await viewModel.tile(page: PageIndex(0), tileRect: rect, scale: 1.0)

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
        let renderCount = await counting.renderCount
        XCTAssertEqual(renderCount, 1, "second request for the same tile should be served from cache")
    }

    func testTileRectsDelegatesToTheInjectedTileGrid() async {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let viewModel = DocumentViewModel(session: session, tileGrid: TileGrid(tileSize: 300))

        let pageSize = PageSize(width: 600, height: 300)
        let rects = viewModel.tileRects(pageSize: pageSize, visibleRect: PDFRect(x: 0, y: 0, width: 600, height: 300), prefetchMargin: 0)

        XCTAssertEqual(rects.count, 2, "a 600x300 page tiled at 300pt should yield exactly 2 tiles")
    }

    func testOpenRestoresAPreviouslySavedScrollPosition() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let store = FakeScrollPositionStore()
        let url = URL(fileURLWithPath: "/tmp/reopen.pdf")
        store.save(ScrollPosition(page: 4, verticalFraction: 0.3), for: url)
        let viewModel = DocumentViewModel(session: session, scrollStore: store)

        await viewModel.open(url: url)

        XCTAssertEqual(viewModel.restoredScrollPosition, ScrollPosition(page: 4, verticalFraction: 0.3))
    }

    func testRecordScrollPositionPersistsAgainstTheOpenedURL() async {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let store = FakeScrollPositionStore()
        let url = URL(fileURLWithPath: "/tmp/record.pdf")
        let viewModel = DocumentViewModel(session: session, scrollStore: store)

        await viewModel.open(url: url)
        viewModel.recordScrollPosition(ScrollPosition(page: 2, verticalFraction: 0))

        XCTAssertEqual(store.position(for: url), ScrollPosition(page: 2, verticalFraction: 0))
    }

    func testReopeningInvalidatesTheTileCacheSoAPriorDocumentsTilesCannotLeak() async throws {
        let engine = FakePDFEngine()
        let counting = CountingRenderer(wrapping: engine)
        let session = DocumentSession(lifecycle: engine, renderer: counting)
        let viewModel = DocumentViewModel(session: session)

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))
        let rect = PDFRect(x: 0, y: 0, width: 200, height: 200)
        _ = await viewModel.tile(page: PageIndex(0), tileRect: rect, scale: 1.0)
        try await session.close()

        await viewModel.open(url: URL(fileURLWithPath: "/tmp/b.pdf"))
        _ = await viewModel.tile(page: PageIndex(0), tileRect: rect, scale: 1.0)

        let renderCount = await counting.renderCount
        XCTAssertEqual(renderCount, 2, "the second document's tile must be rendered again, not served from the first document's cache")
    }
}

/// Test-local `Mock*`: wraps `FakePDFEngine`'s renderer surface to count
/// real render calls, so tests can assert on cache hits without reaching
/// into `TileCache` internals (CLAUDE.md §5 naming: `Mock*` for test-local,
/// vs. `Fake*` shipped in an API package).
private actor CountingRenderer: PageRenderer {
    private let wrapped: FakePDFEngine
    private(set) var renderCount = 0

    init(wrapping wrapped: FakePDFEngine) {
        self.wrapped = wrapped
    }

    func pageCount(of document: DocumentHandle) async throws -> Int {
        try await wrapped.pageCount(of: document)
    }

    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        try await wrapped.metadata(of: document, page: page)
    }

    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        renderCount += 1
        return try await wrapped.renderTile(of: document, request: request)
    }
}
