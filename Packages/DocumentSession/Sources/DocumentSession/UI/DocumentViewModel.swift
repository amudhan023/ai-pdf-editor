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

    /// One sidebar-initiated jump. Wrapped in an identity so two consecutive
    /// clicks on the same page still produce a distinct value — SwiftUI's
    /// `onChange` would otherwise swallow the second navigation.
    public struct NavigationTarget: Equatable {
        public let id: UUID
        public let page: PageIndex

        init(page: PageIndex) {
            self.id = UUID()
            self.page = page
        }
    }

    @Published public private(set) var state: LoadState = .empty
    @Published public private(set) var zoomMode: ZoomMode = .fitWidth
    @Published public private(set) var restoredScrollPosition: ScrollPosition?
    @Published public private(set) var outline: [OutlineNode] = []
    @Published public private(set) var currentPage: PageIndex?
    @Published public private(set) var navigationTarget: NavigationTarget?
    @Published public var thumbnailSelection = ThumbnailSelectionModel()

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
        outline = []
        currentPage = nil
        navigationTarget = nil
        thumbnailSelection.clear()
        do {
            try await session.open(url: url)
            let count = try await session.pageCount()
            openURL = url
            restoredScrollPosition = scrollStore.position(for: url)
            state = .loaded(pageCount: count)
            await loadOutline()
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

    /// The viewer reports each page whose view enters the lazily-rendered
    /// range; the latest report is "current" for sidebar highlighting and
    /// scroll-position persistence (page granularity, per P1-01).
    public func pageDidBecomeVisible(_ page: PageIndex) {
        currentPage = page
        recordScrollPosition(ScrollPosition(page: page.value, verticalFraction: 0))
    }

    /// Sidebar-initiated jump (thumbnail click or outline entry). An outline
    /// destination may carry a zoom target; it is applied before the scroll
    /// so the landing geometry is final.
    public func navigate(to page: PageIndex, zoom: Double? = nil) {
        if let zoom {
            setZoomMode(.custom(zoom))
        }
        navigationTarget = NavigationTarget(page: page)
    }

    /// A failed outline read degrades to "no outline" (sidebar tab shows its
    /// empty state) rather than failing the whole open — the document itself
    /// is still viewable.
    private func loadOutline() async {
        do {
            outline = try await session.outline()
        } catch {
            logger.error("outline read failed; degrading to empty outline")
            outline = []
        }
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

    /// Search wiring: the searcher streams pages through this view model's
    /// session; navigation reuses the sidebar's `navigate(to:)` path so a
    /// result jump and a thumbnail click behave identically.
    public func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searcher: DocumentTextSearcher(session: session)) { [weak self] page in
            self?.navigate(to: page)
        }
    }

    /// Markup wiring (P1-04): shares this view model's session so annotation
    /// CRUD/undo go through the same actor the tile/search paths already use.
    public func makeMarkupToolbarViewModel() -> MarkupToolbarViewModel {
        MarkupToolbarViewModel(session: session)
    }

    /// Comment sidebar wiring (P1-05): reuses the sidebar's `navigate(to:)`
    /// path so selecting a comment jumps the viewer exactly like a thumbnail
    /// or search-result click.
    public func makeCommentSidebarViewModel() -> CommentSidebarViewModel {
        CommentSidebarViewModel(session: session) { [weak self] page in
            self?.navigate(to: page)
        }
    }

    /// Called by the app's memory-pressure source (composition root owns
    /// the `DispatchSourceMemoryPressure`, since its handler fires off this
    /// actor's/object's isolation — see `TileCache.respondToMemoryPressure`).
    public func handleMemoryPressure() async {
        await tileCache.respondToMemoryPressure()
    }
}
