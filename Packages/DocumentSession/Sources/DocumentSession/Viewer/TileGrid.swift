import Foundation
import PDFEngineAPI

/// Divides a page into a fixed-size tile grid and reports which tiles
/// intersect a viewport (plus a prefetch margin) — the "visible-rect-driven
/// tile requests with prefetch" half of P1-01's Requirements, kept as pure
/// geometry so it's cheaply unit-testable independent of any rendering.
public struct TileGrid: Sendable, Equatable {
    /// Tile edge length in page points (pre-scale). Rendering happens at a
    /// separate `scale` (points-to-pixels); this only bounds how much page
    /// area one `TileRenderRequest` covers.
    public let tileSize: Double

    public init(tileSize: Double = 512) {
        precondition(tileSize > 0, "tileSize must be positive")
        self.tileSize = tileSize
    }

    /// All grid-aligned tile rects (in page points) whose bounds intersect
    /// `visibleRect` expanded by `prefetchMargin` on every side, clipped to
    /// `pageSize`. Returns `[]` for a degenerate page or an empty
    /// intersection rather than throwing — this is pure geometry, so an
    /// out-of-range viewport is just "no tiles," not an error.
    public func tiles(for pageSize: PageSize, visibleRect: PDFRect, prefetchMargin: Double = 0) -> [PDFRect] {
        guard pageSize.width > 0, pageSize.height > 0 else { return [] }

        // Clamp the expanded viewport to the page before converting to grid
        // indices, so a viewport that overhangs the page edge (common near
        // the top/bottom of the last page) can't compute a column/row past
        // the page's actual last tile.
        let clampedMinX = max(0, min(pageSize.width, visibleRect.origin.x - prefetchMargin))
        let clampedMinY = max(0, min(pageSize.height, visibleRect.origin.y - prefetchMargin))
        let clampedMaxX = max(0, min(pageSize.width, visibleRect.origin.x + visibleRect.width + prefetchMargin))
        let clampedMaxY = max(0, min(pageSize.height, visibleRect.origin.y + visibleRect.height + prefetchMargin))
        guard clampedMaxX > clampedMinX, clampedMaxY > clampedMinY else { return [] }

        // The last column/row index is `ceil(extent / tileSize) - 1`, not a
        // `floor` with a subtracted epsilon: at scales like 600pt, an
        // epsilon far below `Double`'s precision at that magnitude rounds
        // away to nothing, silently including one extra column/row.
        let lastCol = Int((pageSize.width / tileSize).rounded(.up)) - 1
        let lastRow = Int((pageSize.height / tileSize).rounded(.up)) - 1
        guard lastCol >= 0, lastRow >= 0 else { return [] }

        let minCol = max(0, Int((clampedMinX / tileSize).rounded(.down)))
        let maxCol = min(lastCol, Int((clampedMaxX / tileSize).rounded(.up)) - 1)
        let minRow = max(0, Int((clampedMinY / tileSize).rounded(.down)))
        let maxRow = min(lastRow, Int((clampedMaxY / tileSize).rounded(.up)) - 1)

        guard minCol <= maxCol, minRow <= maxRow else { return [] }

        var rects: [PDFRect] = []
        rects.reserveCapacity((maxCol - minCol + 1) * (maxRow - minRow + 1))
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let x = Double(col) * tileSize
                let y = Double(row) * tileSize
                let width = min(tileSize, pageSize.width - x)
                let height = min(tileSize, pageSize.height - y)
                rects.append(PDFRect(x: x, y: y, width: width, height: height))
            }
        }
        return rects
    }
}
