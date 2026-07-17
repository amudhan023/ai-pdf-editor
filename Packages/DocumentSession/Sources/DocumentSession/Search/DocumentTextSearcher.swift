import Foundation
import PDFEngineAPI

/// One search hit. Granularity is the `TextRun` (frozen seam, ADR-006:
/// one bounding box per run, no per-glyph quads), so `boundingBox` highlights
/// the whole matching run and `snippet` is the run's text — the page-context
/// line the result list shows.
public struct SearchResult: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let page: PageIndex
    public let runID: TextRun.ID
    public let snippet: String
    public let boundingBox: PDFRect

    public init(id: UUID = UUID(), page: PageIndex, runID: TextRun.ID, snippet: String, boundingBox: PDFRect) {
        self.id = id
        self.page = page
        self.runID = runID
        self.snippet = snippet
        self.boundingBox = boundingBox
    }
}

/// Case-, diacritic-, width- and (via NFKC) ligature-insensitive text
/// matching: "fi" finds "ﬁ", "cafe" finds "café", in any script (RTL
/// included — folding is script-neutral).
public enum SearchTextNormalizer {
    public static func fold(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

/// Streaming in-document search: pages are scanned in order and every hit is
/// yielded as soon as its page is processed, so the first results land
/// without waiting for the whole document (the P1-03 large-doc requirement).
/// Cancellation is cooperative per page — cancel the consuming task and the
/// scan stops at the next page boundary.
public struct DocumentTextSearcher: Sendable {
    private let pageCount: @Sendable () async throws -> Int
    private let runsForPage: @Sendable (PageIndex) async throws -> [TextRun]

    public init(
        pageCount: @escaping @Sendable () async throws -> Int,
        runsForPage: @escaping @Sendable (PageIndex) async throws -> [TextRun]
    ) {
        self.pageCount = pageCount
        self.runsForPage = runsForPage
    }

    public init(session: DocumentSession) {
        self.init(
            pageCount: { try await session.pageCount() },
            runsForPage: { try await session.textRuns(page: $0) }
        )
    }

    public func results(for query: String) -> AsyncThrowingStream<SearchResult, Error> {
        let foldedQuery = SearchTextNormalizer.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !foldedQuery.isEmpty else {
                        continuation.finish()
                        return
                    }
                    let count = try await pageCount()
                    for pageIndex in 0..<count {
                        try Task.checkCancellation()
                        let page = PageIndex(pageIndex)
                        for run in try await runsForPage(page)
                        where SearchTextNormalizer.fold(run.text).contains(foldedQuery) {
                            continuation.yield(SearchResult(
                                page: page,
                                runID: run.id,
                                snippet: run.text,
                                boundingBox: run.boundingBox
                            ))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
