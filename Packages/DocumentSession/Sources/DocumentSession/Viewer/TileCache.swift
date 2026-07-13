import Foundation
import PDFEngineAPI

/// Stable, hashable identity for one rendered tile. `Double`s in
/// `TileRenderRequest` aren't `Hashable`-friendly cache keys (float
/// equality drift), so this rounds to a fixed grid the app always renders
/// at (whole page-points, scale to 3 decimal places) — safe because tile
/// rects always come from `TileGrid`, which already produces whole-point
/// rects.
public struct TileKey: Sendable, Hashable {
    public let page: PageIndex
    private let originXMilli: Int
    private let originYMilli: Int
    private let widthMilli: Int
    private let heightMilli: Int
    private let scaleMilli: Int

    public init(page: PageIndex, tileRect: PDFRect, scale: Double) {
        self.page = page
        self.originXMilli = Int((tileRect.origin.x * 1000).rounded())
        self.originYMilli = Int((tileRect.origin.y * 1000).rounded())
        self.widthMilli = Int((tileRect.width * 1000).rounded())
        self.heightMilli = Int((tileRect.height * 1000).rounded())
        self.scaleMilli = Int((scale * 1000).rounded())
    }
}

/// Viewport-driven tile cache: bounded by a total-byte budget (tile
/// payloads vary a lot by page size/scale, so a byte budget bounds memory
/// more directly than an entry-count limit — ARCHITECTURE.md NFR-P2's
/// "bounded memory" requirement) with least-recently-used eviction.
///
/// An actor because tile fetches race across concurrent viewport updates
/// (fast scroll re-requesting overlapping tiles); every access serializes
/// here rather than needing external locking.
public actor TileCache {
    private var storage: [TileKey: RenderedTile] = [:]
    private var order: [TileKey] = [] // index 0 = least recently used
    private var totalBytes = 0
    private let byteBudget: Int

    public init(byteBudget: Int = 256 * 1024 * 1024) {
        precondition(byteBudget > 0, "byteBudget must be positive")
        self.byteBudget = byteBudget
    }

    public var currentByteCount: Int { totalBytes }
    public var entryCount: Int { storage.count }

    public func tile(for key: TileKey) -> RenderedTile? {
        guard let tile = storage[key] else { return nil }
        touch(key)
        return tile
    }

    public func insert(_ tile: RenderedTile, for key: TileKey) {
        remove(key)
        storage[key] = tile
        order.append(key)
        totalBytes += tile.pixelData.count
        evictIfNeeded()
    }

    /// Drops every cached tile for `page` — used when a page's content
    /// changes underneath the cache (edit, rotate) so a stale tile can
    /// never be served.
    public func invalidate(page: PageIndex) {
        for key in order where key.page == page {
            remove(key)
        }
    }

    public func invalidateAll() {
        storage.removeAll()
        order.removeAll()
        totalBytes = 0
    }

    /// Responds to a system memory-pressure signal by evicting down to a
    /// fraction of the normal budget. The app wires this to
    /// `DispatchSource.makeMemoryPressureSource` at the composition root —
    /// an actor can't itself own that GCD source (its handler fires off the
    /// actor's isolation), so this is the call-in point.
    public func respondToMemoryPressure(retaining fraction: Double = 0.25) {
        let clampedFraction = min(1, max(0, fraction))
        let target = Int(Double(byteBudget) * clampedFraction)
        while totalBytes > target, let oldest = order.first {
            remove(oldest)
        }
    }

    private func touch(_ key: TileKey) {
        guard let idx = order.firstIndex(of: key) else { return }
        order.remove(at: idx)
        order.append(key)
    }

    private func remove(_ key: TileKey) {
        if let tile = storage.removeValue(forKey: key) {
            totalBytes -= tile.pixelData.count
        }
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
    }

    private func evictIfNeeded() {
        while totalBytes > byteBudget, let oldest = order.first {
            remove(oldest)
        }
    }
}
