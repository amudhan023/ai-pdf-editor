import Foundation
import PDFEngineAPI

/// Incremental-search state for the viewer's search bar. Each query change
/// cancels the in-flight scan and starts a fresh streaming one — results
/// append as their pages are reached, so the UI shows first hits while a
/// large document is still being scanned (P1-03's responsiveness bar).
@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public private(set) var results: [SearchResult] = []
    @Published public private(set) var currentResultIndex: Int?
    @Published public private(set) var isSearching = false
    /// Run-granularity highlight rects per page, for the tile view overlay.
    @Published public private(set) var highlightsByPage: [PageIndex: [PDFRect]] = [:]

    public private(set) var query: String = ""

    private let searcher: DocumentTextSearcher
    private let onNavigate: (PageIndex) -> Void
    private var searchTask: Task<Void, Never>?

    public init(searcher: DocumentTextSearcher, onNavigate: @escaping (PageIndex) -> Void) {
        self.searcher = searcher
        self.onNavigate = onNavigate
    }

    public var currentResult: SearchResult? {
        currentResultIndex.flatMap { results.indices.contains($0) ? results[$0] : nil }
    }

    public func updateQuery(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()
        results = []
        currentResultIndex = nil
        highlightsByPage = [:]
        guard !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [searcher] in
            do {
                for try await result in searcher.results(for: newQuery) {
                    guard !Task.isCancelled else { return }
                    append(result)
                }
            } catch is CancellationError {
                return
            } catch {
                // A page failing extraction degrades to "no results from
                // that page" — partial results already shown stay valid.
            }
            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    public func nextResult() {
        step(by: 1)
    }

    public func previousResult() {
        step(by: -1)
    }

    private func step(by delta: Int) {
        guard !results.isEmpty else { return }
        let next: Int
        if let current = currentResultIndex {
            next = (current + delta + results.count) % results.count
        } else {
            next = delta >= 0 ? 0 : results.count - 1
        }
        currentResultIndex = next
        onNavigate(results[next].page)
    }

    public func select(_ result: SearchResult) {
        guard let index = results.firstIndex(of: result) else { return }
        currentResultIndex = index
        onNavigate(result.page)
    }

    private func append(_ result: SearchResult) {
        results.append(result)
        highlightsByPage[result.page, default: []].append(result.boundingBox)
        if currentResultIndex == nil {
            currentResultIndex = 0
            onNavigate(result.page)
        }
    }
}
