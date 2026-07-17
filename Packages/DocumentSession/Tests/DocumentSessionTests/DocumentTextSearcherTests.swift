import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class DocumentTextSearcherTests: XCTestCase {
    private func run(_ text: String, page: Int, y: Double = 700) -> TextRun {
        TextRun(page: PageIndex(page), text: text, boundingBox: PDFRect(x: 72, y: y, width: 200, height: 14), fontSize: 12)
    }

    private func searcher(pages: [[TextRun]]) -> DocumentTextSearcher {
        DocumentTextSearcher(
            pageCount: { pages.count },
            runsForPage: { pages[$0.value] }
        )
    }

    private func collect(_ searcher: DocumentTextSearcher, query: String) async throws -> [SearchResult] {
        var collected: [SearchResult] = []
        for try await result in searcher.results(for: query) {
            collected.append(result)
        }
        return collected
    }

    func testFindsMatchesInPageOrderWithSnippetsAndGeometry() async throws {
        let searcher = searcher(pages: [
            [run("Alpha ridge report", page: 0), run("nothing here", page: 0, y: 650)],
            [run("second ALPHA mention", page: 1)]
        ])

        let results = try await collect(searcher, query: "alpha")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].page, PageIndex(0))
        XCTAssertEqual(results[0].snippet, "Alpha ridge report")
        XCTAssertEqual(results[0].boundingBox, PDFRect(x: 72, y: 700, width: 200, height: 14))
        XCTAssertEqual(results[1].page, PageIndex(1))
    }

    func testSearchIsCaseAndDiacriticInsensitive() async throws {
        let searcher = searcher(pages: [[run("Visite au CAFÉ Noël", page: 0)]])

        let byPlain = try await collect(searcher, query: "cafe noel")
        let byAccented = try await collect(searcher, query: "CAFÉ NOËL")

        XCTAssertEqual(byPlain.count, 1)
        XCTAssertEqual(byAccented.count, 1)
    }

    /// Ligature fixture (task Testing Requirements): PDFs frequently encode
    /// "fi"/"fl" as single ligature glyphs, which extraction surfaces as the
    /// Unicode ligature characters — searching the plain letters must match.
    func testLigaturesMatchTheirPlainLetterForms() async throws {
        let searcher = searcher(pages: [[run("con\u{FB01}dential \u{FB02}ight plan", page: 0)]])

        let fiResults = try await collect(searcher, query: "confidential")
        let flResults = try await collect(searcher, query: "flight")

        XCTAssertEqual(fiResults.count, 1)
        XCTAssertEqual(flResults.count, 1)
    }

    /// RTL fixture (task Testing Requirements): Arabic text matches by
    /// substring exactly like LTR scripts — folding is script-neutral.
    func testRTLTextMatches() async throws {
        let searcher = searcher(pages: [[run("عقد الإيجار السنوي", page: 0)]])

        let results = try await collect(searcher, query: "الإيجار")

        XCTAssertEqual(results.count, 1)
    }

    func testEmptyAndWhitespaceQueriesYieldNothing() async throws {
        let searcher = searcher(pages: [[run("anything", page: 0)]])

        let empty = try await collect(searcher, query: "")
        let blank = try await collect(searcher, query: "   ")

        XCTAssertTrue(empty.isEmpty)
        XCTAssertTrue(blank.isEmpty)
    }

    /// The streaming contract behind the "<300ms first results on 500 pages"
    /// acceptance bar, asserted structurally instead of with a wall clock:
    /// the first result must be yielded before later pages are even visited.
    func testStreamsFirstResultBeforeScanningLaterPages() async throws {
        let visited = VisitedPages()
        let searcher = DocumentTextSearcher(
            pageCount: { 500 },
            runsForPage: { page in
                await visited.note(page.value)
                return [TextRun(page: page, text: "match on every page", boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10), fontSize: 12)]
            }
        )

        var iterator = searcher.results(for: "match").makeAsyncIterator()
        let first = try await iterator.next()

        XCTAssertNotNil(first)
        let maxVisited = await visited.maxPage
        XCTAssertLessThan(maxVisited, 499, "the first result must arrive while later pages are still unscanned")
    }

    func testCancellationStopsTheScanAtAPageBoundary() async throws {
        let visited = VisitedPages()
        let searcher = DocumentTextSearcher(
            pageCount: { 500 },
            runsForPage: { page in
                await visited.note(page.value)
                return []
            }
        )

        let consumer = Task {
            for try await _ in searcher.results(for: "never-found") {}
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        consumer.cancel()
        _ = try? await consumer.value
        let afterCancel = await visited.count
        try await Task.sleep(nanoseconds: 50_000_000)
        let later = await visited.count
        XCTAssertLessThanOrEqual(later, afterCancel + 1, "cancellation must stop the scan within one page")
    }

    func testExtractionErrorSurfacesThroughTheStream() async {
        let searcher = DocumentTextSearcher(
            pageCount: { 1 },
            runsForPage: { _ in throw PDFEngineError.ioFailure("boom") }
        )

        do {
            for try await _ in searcher.results(for: "x") {}
            XCTFail("an extraction error must surface, not be swallowed")
        } catch {
            // expected
        }
    }

    func testSessionWithoutTextEditorYieldsNoResults() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/no-text-editor.pdf"))

        let results = try await collect(DocumentTextSearcher(session: session), query: "anything")

        XCTAssertTrue(results.isEmpty)
    }
}

private actor VisitedPages {
    private(set) var maxPage = -1
    private(set) var count = 0

    func note(_ page: Int) {
        maxPage = max(maxPage, page)
        count += 1
    }
}
