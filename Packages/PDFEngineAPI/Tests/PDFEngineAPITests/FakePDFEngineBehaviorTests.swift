import XCTest
@testable import PDFEngineAPI

/// Behavior not covered by the generic conformance suite: page-organizer
/// operations, text-run replacement, document lifecycle, and error paths.
final class FakePDFEngineBehaviorTests: XCTestCase {
    func testPageOrganizerInsertDeleteReorderRotate() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument(pageCount: 2)
        let source = await engine.seedDocument(pageCount: 1)

        try await engine.apply(.insert(from: source, sourcePage: PageIndex(0), at: PageIndex(1)), to: document)
        var count = try await engine.pageCount(of: document)
        XCTAssertEqual(count, 3)

        try await engine.apply(.rotate(PageIndex(1), by: .clockwise90), to: document)
        let rotated = try await engine.metadata(of: document, page: PageIndex(1))
        XCTAssertEqual(rotated.rotation, .clockwise90)

        try await engine.apply(.reorder(from: PageIndex(1), to: PageIndex(0)), to: document)
        let movedFirst = try await engine.metadata(of: document, page: PageIndex(0))
        XCTAssertEqual(movedFirst.rotation, .clockwise90)

        try await engine.apply(.delete(PageIndex(0)), to: document)
        count = try await engine.pageCount(of: document)
        XCTAssertEqual(count, 2)
    }

    func testPageOrganizerRejectsOutOfRangeIndex() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument()
        do {
            try await engine.apply(.delete(PageIndex(99)), to: document)
            XCTFail("expected pageIndexOutOfRange")
        } catch PDFEngineError.pageIndexOutOfRange {
            // expected
        }
    }

    func testTextEditorReplace() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument()
        let run = TextRun(page: PageIndex(0), text: "old", boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10), fontSize: 12)
        try await engine.seedTextRuns([run], for: document)

        try await engine.replaceText(of: document, run: run.id, with: "new")
        let runs = try await engine.textRuns(of: document, page: PageIndex(0))
        XCTAssertEqual(runs.first?.text, "new")
    }

    func testOutlineSeedAndReadRoundTripsNestedTree() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument(pageCount: 5)
        let child = OutlineNode(title: "Section 1.1", destinationPage: PageIndex(2), zoom: 1.5)
        let root = OutlineNode(title: "Section 1", destinationPage: PageIndex(1), children: [child])
        try await engine.seedOutline([root], for: document)

        let outline = try await engine.outline(of: document)
        XCTAssertEqual(outline.count, 1)
        XCTAssertEqual(outline.first?.title, "Section 1")
        XCTAssertEqual(outline.first?.children.first?.title, "Section 1.1")
        XCTAssertEqual(outline.first?.children.first?.destinationPage, PageIndex(2))
        XCTAssertEqual(outline.first?.children.first?.zoom, 1.5)
    }

    func testDocumentLifecycle() async throws {
        let engine = FakePDFEngine()
        let document = try await engine.open(url: URL(fileURLWithPath: "/tmp/does-not-matter.pdf"))
        _ = try await engine.pageCount(of: document)

        try await engine.save(document, mode: .incremental, to: URL(fileURLWithPath: "/tmp/does-not-matter.pdf"))
        try await engine.close(document)

        do {
            _ = try await engine.pageCount(of: document)
            XCTFail("expected documentNotFound after close")
        } catch PDFEngineError.documentNotFound {
            // expected
        }
    }
}
