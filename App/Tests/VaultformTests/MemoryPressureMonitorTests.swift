import XCTest
import PDFEngineAPI
import DocumentSession
@testable import Vaultform

final class MemoryPressureMonitorTests: XCTestCase {
    func testSimulatedPressureEventInvokesTheHandler() {
        let fired = expectation(description: "onPressure invoked")
        let monitor = MemoryPressureMonitor { fired.fulfill() }

        monitor.simulatePressureEvent()

        wait(for: [fired], timeout: 1.0)
    }

    /// P1-19 acceptance criterion end-to-end minus the GCD source itself: a
    /// pressure event, routed exactly the way `AppDelegate` wires it,
    /// measurably shrinks `TileCache.currentByteCount` toward the retain
    /// fraction. The budget is set just above one tile's size so the 25%
    /// retain target forces the eviction to be observable.
    @MainActor
    func testPressureEventShrinksThePopulatedTileCache() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        let tileRect = PDFRect(x: 0, y: 0, width: 100, height: 100)
        let tileBytes = 100 * 100 * 4
        let tileCache = TileCache(byteBudget: tileBytes + 1)
        let viewModel = DocumentViewModel(session: session, tileCache: tileCache)
        await viewModel.open(url: URL(fileURLWithPath: "/tmp/pressure.pdf"))
        _ = await viewModel.tile(page: PageIndex(0), tileRect: tileRect, scale: 1.0)
        let populatedBytes = await tileCache.currentByteCount
        XCTAssertEqual(populatedBytes, tileBytes, "precondition: the rendered tile must be in the cache")

        let monitor = MemoryPressureMonitor {
            Task { @MainActor in
                await viewModel.handleMemoryPressure()
            }
        }
        monitor.simulatePressureEvent()

        // The handler hops to the main actor via an unstructured Task; poll
        // briefly rather than assuming scheduling order.
        var afterPressure = populatedBytes
        for _ in 0..<50 {
            afterPressure = await tileCache.currentByteCount
            if afterPressure < populatedBytes { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertLessThan(afterPressure, populatedBytes, "pressure must evict down toward the retain fraction of the budget")
    }
}
