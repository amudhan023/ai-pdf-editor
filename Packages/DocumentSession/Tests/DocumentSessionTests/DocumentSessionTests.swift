import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class DocumentSessionTests: XCTestCase {
    func testOpenThenPageCountAndMetadataReflectTheEngine() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)

        try await session.open(url: URL(fileURLWithPath: "/tmp/doesnotneedtoexist.pdf"))

        let count = try await session.pageCount()
        XCTAssertEqual(count, 1)
        let metadata = try await session.metadata(page: PageIndex(0))
        XCTAssertEqual(metadata.index, PageIndex(0))
    }

    func testRenderTileDelegatesToTheRenderer() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/doesnotneedtoexist.pdf"))

        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 612, height: 792), scale: 1.0)
        let tile = try await session.renderTile(request)

        XCTAssertEqual(tile.pixelWidth, 612)
        XCTAssertEqual(tile.pixelHeight, 792)
    }

    func testOpeningTwiceThrowsAlreadyOpenAndLeavesTheFirstDocumentUsable() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))

        do {
            try await session.open(url: URL(fileURLWithPath: "/tmp/b.pdf"))
            XCTFail("expected .alreadyOpen")
        } catch DocumentSessionError.alreadyOpen {
            // expected
        }

        let count = try await session.pageCount()
        XCTAssertEqual(count, 1, "first document must still be usable after the rejected second open")
    }

    func testOperationsBeforeOpenThrowNotOpen() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)

        do {
            _ = try await session.pageCount()
            XCTFail("expected .notOpen")
        } catch DocumentSessionError.notOpen {
            // expected
        }
    }

    func testCloseThenOperationsThrowNotOpen() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))
        try await session.close()

        do {
            _ = try await session.pageCount()
            XCTFail("expected .notOpen")
        } catch DocumentSessionError.notOpen {
            // expected
        }
    }

    /// `FakePDFEngine.open` never fails, so a `Mock*` stand-in exercises the
    /// unopenable-file surface (CLAUDE.md §5 naming; matches AtomicSaveTests'
    /// `MockLifecycle`) — the acceptance criterion this task actually cares
    /// about is that the failure comes back typed, never a crash.
    func testUnopenableFileSurfacesATypedEngineError() async throws {
        let engine = FailingOpenEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)

        do {
            try await session.open(url: URL(fileURLWithPath: "/tmp/corrupt.pdf"))
            XCTFail("expected .engine(.corruptDocument)")
        } catch DocumentSessionError.engine(.corruptDocument) {
            // expected
        }

        let stillOpen = await session.isOpen
        XCTAssertFalse(stillOpen)
    }
}

private actor FailingOpenEngine: DocumentLifecycle, PageRenderer {
    func open(url: URL) async throws -> DocumentHandle {
        throw PDFEngineError.corruptDocument(reason: "mock: not a PDF")
    }

    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {}
    func close(_ document: DocumentHandle) async throws {}

    func pageCount(of document: DocumentHandle) async throws -> Int {
        throw PDFEngineError.documentNotFound(document)
    }

    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        throw PDFEngineError.documentNotFound(document)
    }

    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        throw PDFEngineError.documentNotFound(document)
    }
}
