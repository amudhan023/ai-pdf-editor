import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class TileGridTests: XCTestCase {
    func testFullPageRectAtOriginProducesTilesCoveringTheWholePage() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 612, height: 792) // US Letter
        let fullRect = PDFRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)

        let tiles = grid.tiles(for: pageSize, visibleRect: fullRect)

        // 612/512 -> 2 columns, 792/512 -> 2 rows.
        XCTAssertEqual(tiles.count, 4)
        let totalArea = tiles.reduce(0.0) { $0 + $1.width * $1.height }
        XCTAssertEqual(totalArea, pageSize.width * pageSize.height, accuracy: 0.001)
    }

    func testTilesAtPageEdgesAreClippedNotOverhanging() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 612, height: 792)
        let fullRect = PDFRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)

        let tiles = grid.tiles(for: pageSize, visibleRect: fullRect)

        for tile in tiles {
            XCTAssertLessThanOrEqual(tile.origin.x + tile.width, pageSize.width + 0.001)
            XCTAssertLessThanOrEqual(tile.origin.y + tile.height, pageSize.height + 0.001)
        }
    }

    func testSmallVisibleRectOnlyReturnsIntersectingTiles() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 1024, height: 1024) // 2x2 grid
        let topLeftOnly = PDFRect(x: 0, y: 0, width: 100, height: 100)

        let tiles = grid.tiles(for: pageSize, visibleRect: topLeftOnly)

        XCTAssertEqual(tiles.count, 1)
        XCTAssertEqual(tiles[0].origin.x, 0)
        XCTAssertEqual(tiles[0].origin.y, 0)
    }

    func testPrefetchMarginPullsInNeighboringTiles() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 1536, height: 512) // 3x1 grid
        let middleTileOnly = PDFRect(x: 512, y: 0, width: 1, height: 1)

        let withoutMargin = grid.tiles(for: pageSize, visibleRect: middleTileOnly, prefetchMargin: 0)
        let withMargin = grid.tiles(for: pageSize, visibleRect: middleTileOnly, prefetchMargin: 600)

        XCTAssertEqual(withoutMargin.count, 1)
        XCTAssertEqual(withMargin.count, 3, "a wide-enough margin should pull in both neighbors")
    }

    func testViewportPastThePageEdgeReturnsNoTilesBeyondTheLastRow() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 512, height: 512) // exactly 1x1 grid
        let overhanging = PDFRect(x: 0, y: 400, width: 512, height: 600)

        let tiles = grid.tiles(for: pageSize, visibleRect: overhanging)

        XCTAssertEqual(tiles.count, 1)
    }

    func testZeroSizedPageReturnsNoTiles() {
        let grid = TileGrid(tileSize: 512)
        let pageSize = PageSize(width: 0, height: 0)
        let rect = PDFRect(x: 0, y: 0, width: 100, height: 100)

        XCTAssertTrue(grid.tiles(for: pageSize, visibleRect: rect).isEmpty)
    }
}
