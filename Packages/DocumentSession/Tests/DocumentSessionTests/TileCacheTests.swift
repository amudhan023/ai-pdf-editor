import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class TileCacheTests: XCTestCase {
    private func makeTile(request: TileRenderRequest, byteCount: Int) -> RenderedTile {
        RenderedTile(request: request, pixelWidth: 1, pixelHeight: 1, pixelData: Data(repeating: 0, count: byteCount))
    }

    func testInsertThenFetchReturnsTheSameTile() async {
        let cache = TileCache(byteBudget: 1_000_000)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 512, height: 512), scale: 1.0)
        let key = TileKey(page: PageIndex(0), tileRect: request.tileRect, scale: 1.0)
        let tile = makeTile(request: request, byteCount: 100)

        await cache.insert(tile, for: key)
        let fetched = await cache.tile(for: key)

        XCTAssertEqual(fetched, tile)
    }

    func testMissReturnsNil() async {
        let cache = TileCache(byteBudget: 1_000_000)
        let key = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)

        let fetched = await cache.tile(for: key)

        XCTAssertNil(fetched)
    }

    func testEvictsLeastRecentlyUsedWhenOverBudget() async {
        let cache = TileCache(byteBudget: 250)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let keyA = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let keyB = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 512, y: 0, width: 1, height: 1), scale: 1.0)
        let keyC = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 1024, y: 0, width: 1, height: 1), scale: 1.0)

        await cache.insert(makeTile(request: request, byteCount: 100), for: keyA)
        await cache.insert(makeTile(request: request, byteCount: 100), for: keyB)
        // Touch A so B becomes the least-recently-used entry.
        _ = await cache.tile(for: keyA)
        await cache.insert(makeTile(request: request, byteCount: 100), for: keyC)

        let a = await cache.tile(for: keyA)
        let b = await cache.tile(for: keyB)
        let c = await cache.tile(for: keyC)

        XCTAssertNotNil(a, "recently-touched entry should survive eviction")
        XCTAssertNil(b, "least-recently-used entry should be evicted first")
        XCTAssertNotNil(c)
    }

    func testByteCountTracksInsertionsAndEvictions() async {
        let cache = TileCache(byteBudget: 1_000_000)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let key = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)

        await cache.insert(makeTile(request: request, byteCount: 4096), for: key)
        let count = await cache.currentByteCount
        XCTAssertEqual(count, 4096)

        await cache.invalidateAll()
        let afterInvalidate = await cache.currentByteCount
        XCTAssertEqual(afterInvalidate, 0)
    }

    func testInvalidatePageOnlyRemovesThatPagesTiles() async {
        let cache = TileCache(byteBudget: 1_000_000)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let keyPage0 = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let keyPage1 = TileKey(page: PageIndex(1), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)

        await cache.insert(makeTile(request: request, byteCount: 10), for: keyPage0)
        await cache.insert(makeTile(request: request, byteCount: 10), for: keyPage1)

        await cache.invalidate(page: PageIndex(0))

        let page0 = await cache.tile(for: keyPage0)
        let page1 = await cache.tile(for: keyPage1)
        XCTAssertNil(page0)
        XCTAssertNotNil(page1)
    }

    func testRespondToMemoryPressureEvictsDownToTheRetainedFraction() async {
        let cache = TileCache(byteBudget: 1000)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        for i in 0..<10 {
            let key = TileKey(page: PageIndex(0), tileRect: PDFRect(x: Double(i) * 512, y: 0, width: 1, height: 1), scale: 1.0)
            await cache.insert(makeTile(request: request, byteCount: 100), for: key)
        }
        let beforeCount = await cache.currentByteCount
        XCTAssertEqual(beforeCount, 1000)

        await cache.respondToMemoryPressure(retaining: 0.25)

        let remaining = await cache.currentByteCount
        XCTAssertLessThanOrEqual(remaining, 250)
    }

    func testReinsertingTheSameKeyReplacesRatherThanDoubleCountingBytes() async {
        let cache = TileCache(byteBudget: 1_000_000)
        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)
        let key = TileKey(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 1, height: 1), scale: 1.0)

        await cache.insert(makeTile(request: request, byteCount: 500), for: key)
        await cache.insert(makeTile(request: request, byteCount: 700), for: key)

        let byteCount = await cache.currentByteCount
        let entryCount = await cache.entryCount
        XCTAssertEqual(byteCount, 700)
        XCTAssertEqual(entryCount, 1)
    }
}
