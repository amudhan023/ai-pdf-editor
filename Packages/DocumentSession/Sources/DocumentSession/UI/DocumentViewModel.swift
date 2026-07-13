import Foundation
import PDFEngineAPI
import os

/// `@MainActor` presentation-facing wrapper around the `DocumentSession`
/// actor — SwiftUI views bind to `@Published` state here rather than
/// talking to the actor directly, since view updates must happen on the
/// main actor and `DocumentSession` itself is engine-isolated, not UI-isolated.
@MainActor
public final class DocumentViewModel: ObservableObject {
    public enum LoadState: Equatable {
        case empty
        case loading
        case loaded(pageCount: Int)
        case failed(DocumentSessionError)
    }

    @Published public private(set) var state: LoadState = .empty
    @Published public private(set) var zoomMode: ZoomMode = .fitWidth
    @Published public private(set) var restoredScrollPosition: ScrollPosition?

    private let session: DocumentSession
    private let tileCache: TileCache
    private let tileGrid: TileGrid
    private let scrollStore: ScrollPositionStoring
    private var openURL: URL?
    private let logger = Logger(subsystem: "com.vaultform.app", category: "DocumentViewModel")

    public init(
        session: DocumentSession,
        tileCache: TileCache = TileCache(),
        tileGrid: TileGrid = TileGrid(),
        scrollStore: ScrollPositionStoring = UserDefaultsScrollPositionStore()
    ) {
        self.session = session
        self.tileCache = tileCache
        self.tileGrid = tileGrid
        self.scrollStore = scrollStore
    }

    public func open(url: URL) async {
        state = .loading
        await tileCache.invalidateAll()
        do {
            try await session.open(url: url)
            let count = try await session.pageCount()
            openURL = url
            restoredScrollPosition = scrollStore.position(for: url)
            state = .loaded(pageCount: count)
        } catch let error as DocumentSessionError {
            logger.error("open failed: \(error.userMessageKey, privacy: .public)")
            state = .failed(error)
        } catch {
            logger.error("open failed with unexpected error type")
            state = .failed(.engine(.ioFailure("\(error)")))
        }
    }

    public func setZoomMode(_ mode: ZoomMode) {
        switch mode {
        case .custom(let value):
            zoomMode = .custom(ZoomMath.clamp(value))
        case .fitPage, .fitWidth:
            zoomMode = mode
        }
    }

    public func recordScrollPosition(_ position: ScrollPosition) {
        guard let openURL else { return }
        scrollStore.save(position, for: openURL)
    }

    /// Fetches one tile at `scale`, cache-first: a cache hit returns
    /// immediately with no engine round-trip; a miss renders through the
    /// session and populates the cache for the next request covering the
    /// same rect (P1-01's "visible-rect-driven tile requests" contract).
    public func tile(page: PageIndex, tileRect: PDFRect, scale: Double) async -> RenderedTile? {
        guard case .loaded = state else { return nil }
        let key = TileKey(page: page, tileRect: tileRect, scale: scale)
        if let cached = await tileCache.tile(for: key) {
            return cached
        }
        do {
            let request = TileRenderRequest(page: page, tileRect: tileRect, scale: scale)
            let rendered = try await session.renderTile(request)
            await tileCache.insert(rendered, for: key)
            return rendered
        } catch {
            logger.error("tile render failed for page \(page.value, privacy: .public)")
            return nil
        }
    }

    /// All grid tiles intersecting `visibleRect` (page points) expanded by
    /// `prefetchMargin`, in prefetch order — callers request these in order
    /// so the currently-visible tiles resolve before pure prefetch ones.
    public func tileRects(pageSize: PageSize, visibleRect: PDFRect, prefetchMargin: Double) -> [PDFRect] {
        tileGrid.tiles(for: pageSize, visibleRect: visibleRect, prefetchMargin: prefetchMargin)
    }

    public func metadata(page: PageIndex) async -> PageMetadata? {
        guard case .loaded = state else { return nil }
        return try? await session.metadata(page: page)
    }

    /// Called by the app's memory-pressure source (composition root owns
    /// the `DispatchSourceMemoryPressure`, since its handler fires off this
    /// actor's/object's isolation — see `TileCache.respondToMemoryPressure`).
    public func handleMemoryPressure() async {
        await tileCache.respondToMemoryPressure()
    }
}
