import XCTest
import PDFEngineAPI
@testable import DocumentSession

@MainActor
final class SearchViewModelTests: XCTestCase {
    private func makeSearchViewModel(
        pages: [[TextRun]],
        onNavigate: @escaping (PageIndex) -> Void = { _ in }
    ) -> SearchViewModel {
        SearchViewModel(
            searcher: DocumentTextSearcher(pageCount: { pages.count }, runsForPage: { pages[$0.value] }),
            onNavigate: onNavigate
        )
    }

    private func run(_ text: String, page: Int) -> TextRun {
        TextRun(page: PageIndex(page), text: text, boundingBox: PDFRect(x: 10, y: 10, width: 100, height: 12), fontSize: 12)
    }

    private func waitUntilDoneSearching(_ viewModel: SearchViewModel) async throws {
        for _ in 0..<400 {
            if !viewModel.isSearching { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("search did not finish")
    }

    func testQueryPopulatesResultsHighlightsAndJumpsToFirstHit() async throws {
        var navigations: [PageIndex] = []
        let viewModel = makeSearchViewModel(
            pages: [[run("no hit", page: 0)], [run("target text", page: 1)], [run("another target", page: 2)]],
            onNavigate: { navigations.append($0) }
        )

        viewModel.updateQuery("target")
        try await waitUntilDoneSearching(viewModel)

        XCTAssertEqual(viewModel.results.count, 2)
        XCTAssertEqual(viewModel.currentResultIndex, 0)
        XCTAssertEqual(navigations.first, PageIndex(1), "first hit navigates immediately")
        XCTAssertEqual(viewModel.highlightsByPage[PageIndex(1)]?.count, 1)
        XCTAssertEqual(viewModel.highlightsByPage[PageIndex(2)]?.count, 1)
    }

    func testNextAndPreviousWrapAndNavigate() async throws {
        var navigations: [PageIndex] = []
        let viewModel = makeSearchViewModel(
            pages: [[run("hit one", page: 0)], [run("hit two", page: 1)]],
            onNavigate: { navigations.append($0) }
        )
        viewModel.updateQuery("hit")
        try await waitUntilDoneSearching(viewModel)

        viewModel.nextResult()
        XCTAssertEqual(viewModel.currentResultIndex, 1)
        viewModel.nextResult()
        XCTAssertEqual(viewModel.currentResultIndex, 0, "next past the end wraps to the first result")
        viewModel.previousResult()
        XCTAssertEqual(viewModel.currentResultIndex, 1, "previous before the start wraps to the last result")
        XCTAssertEqual(navigations.count, 4, "initial jump + three steps")
    }

    func testNewQueryReplacesPriorResultsAndHighlights() async throws {
        let viewModel = makeSearchViewModel(pages: [[run("apples and oranges", page: 0)]])
        viewModel.updateQuery("apples")
        try await waitUntilDoneSearching(viewModel)
        XCTAssertEqual(viewModel.results.count, 1)

        viewModel.updateQuery("bananas")
        try await waitUntilDoneSearching(viewModel)

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertTrue(viewModel.highlightsByPage.isEmpty)
        XCTAssertNil(viewModel.currentResultIndex)
    }

    func testClearingTheQueryStopsSearchingAndEmptiesState() async throws {
        let viewModel = makeSearchViewModel(pages: [[run("something", page: 0)]])
        viewModel.updateQuery("something")
        try await waitUntilDoneSearching(viewModel)

        viewModel.updateQuery("")

        XCTAssertFalse(viewModel.isSearching)
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertTrue(viewModel.highlightsByPage.isEmpty)
    }

    func testSelectingAListedResultNavigatesToItsPage() async throws {
        var navigations: [PageIndex] = []
        let viewModel = makeSearchViewModel(
            pages: [[run("pick me", page: 0)], [run("pick me too", page: 1)]],
            onNavigate: { navigations.append($0) }
        )
        viewModel.updateQuery("pick")
        try await waitUntilDoneSearching(viewModel)

        viewModel.select(viewModel.results[1])

        XCTAssertEqual(viewModel.currentResultIndex, 1)
        XCTAssertEqual(navigations.last, PageIndex(1))
    }
}
