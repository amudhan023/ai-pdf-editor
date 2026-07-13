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

    private let session: DocumentSession
    private let logger = Logger(subsystem: "com.vaultform.app", category: "DocumentViewModel")

    public init(session: DocumentSession) {
        self.session = session
    }

    public func open(url: URL) async {
        state = .loading
        do {
            try await session.open(url: url)
            let count = try await session.pageCount()
            state = .loaded(pageCount: count)
        } catch let error as DocumentSessionError {
            logger.error("open failed: \(error.userMessageKey, privacy: .public)")
            state = .failed(error)
        } catch {
            logger.error("open failed with unexpected error type")
            state = .failed(.engine(.ioFailure("\(error)")))
        }
    }

    /// Fetches one page rendered as a single naive full-page tile (no
    /// sub-tiling yet — that's P1-01's real tiling scope per this task's
    /// Requirements) at the given `scale` (points-to-pixels).
    public func pageImage(page: PageIndex, scale: Double) async -> PageImage? {
        guard case .loaded = state else { return nil }
        do {
            let metadata = try await session.metadata(page: page)
            let request = TileRenderRequest(
                page: page,
                tileRect: PDFRect(x: 0, y: 0, width: metadata.size.width, height: metadata.size.height),
                scale: scale
            )
            let tile = try await session.renderTile(request)
            return PageImage(tile: tile, pointSize: metadata.size)
        } catch {
            logger.error("page render failed for page \(page.value, privacy: .public)")
            return nil
        }
    }
}

/// A rendered page ready for display: raw RGBA8 pixels plus the page-point
/// size the view should lay the image out at (independent of the pixel
/// dimensions, which reflect `scale`).
public struct PageImage: Sendable, Equatable {
    public let tile: RenderedTile
    public let pointSize: PageSize
}
