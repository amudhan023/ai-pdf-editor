import DocumentSession
import PDFEngineAPI
import Foundation

// Scripted scroll-perf bench for Scripts/bench.sh's `tile-scroll` suite
// (P1-01): simulates scrolling through a synthetic multi-page document,
// measuring cache-miss (first render) vs. cache-hit (re-scroll) tile-fetch
// latency and the final cache footprint against its configured budget.
//
// This measures DocumentSession's TileCache/TileGrid contract, not a real
// on-screen frame rate: this package's import allowlist has no
// DocEngineHost entry (PDFEngineAPI protocols + Platform only), so there is
// no real PDFium render cost or display here to sample against NFR-P2's
// 60fps budget directly - DocEngineHost's `render-latency` suite already
// covers real per-tile PDFium latency. What this bench actually pins: a
// cache hit must be dramatically cheaper than a miss (no re-render, no
// engine round-trip), which is the load-bearing property behind "no
// blank-tile flashes at p95 during fast scroll" (P1-01 Acceptance Criteria)
// once wired to a real engine.

let pageCount = 50
let pageSize = PageSize(width: 612, height: 792)
let byteBudget = 64 * 1024 * 1024

final class Results: @unchecked Sendable {
    var missSamplesMs: [Double] = []
    var hitSamplesMs: [Double] = []
    var finalByteCount = 0
    var tilesPerPage = 0
    var isDone = false
}
let results = Results()

func percentile(_ samples: [Double], _ p: Double) -> Double {
    guard !samples.isEmpty else { return 0 }
    let sorted = samples.sorted()
    let idx = min(sorted.count - 1, max(0, Int((p / 100) * Double(sorted.count))))
    return sorted[idx]
}

Task {
    let engine = FakePDFEngine()
    let cache = TileCache(byteBudget: byteBudget)
    let grid = TileGrid(tileSize: 512)
    let session = DocumentSession(lifecycle: engine, renderer: engine)
    let viewModel = DocumentViewModel(session: session, tileCache: cache, tileGrid: grid)

    _ = await engine.seedDocument(pageCount: pageCount, pageSize: pageSize)
    await viewModel.open(url: URL(fileURLWithPath: "/tmp/tile-scroll-bench.pdf"))

    let fullRect = PDFRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
    let rects = grid.tiles(for: pageSize, visibleRect: fullRect)
    results.tilesPerPage = rects.count

    // First pass down the document: every tile is a cache miss.
    for pageIndex in 0..<pageCount {
        let page = PageIndex(pageIndex)
        for rect in rects {
            let start = DispatchTime.now()
            _ = await viewModel.tile(page: page, tileRect: rect, scale: 1.0)
            let end = DispatchTime.now()
            results.missSamplesMs.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
        }
    }

    // Scroll back up: every tile should now be a cache hit.
    for pageIndex in 0..<pageCount {
        let page = PageIndex(pageIndex)
        for rect in rects {
            let start = DispatchTime.now()
            _ = await viewModel.tile(page: page, tileRect: rect, scale: 1.0)
            let end = DispatchTime.now()
            results.hitSamplesMs.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
        }
    }

    results.finalByteCount = await cache.currentByteCount
    results.isDone = true
}
while !results.isDone {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
}

let missP50 = percentile(results.missSamplesMs, 50)
let hitP50 = percentile(results.hitSamplesMs, 50)
let hitP95 = percentile(results.hitSamplesMs, 95)

// The contract this bench actually pins, given no real engine/display here.
let status = (hitP50 <= missP50) ? "pass" : "fail"

let result: [String: Any] = [
    "suite": "tile-scroll",
    "status": status,
    "page_count": pageCount,
    "tiles_per_page": results.tilesPerPage,
    "tiles_sampled": results.missSamplesMs.count,
    "cache_miss_p50_ms": (missP50 * 1000).rounded() / 1000,
    "cache_hit_p50_ms": (hitP50 * 1000).rounded() / 1000,
    "cache_hit_p95_ms": (hitP95 * 1000).rounded() / 1000,
    "byte_budget": byteBudget,
    "final_cache_bytes": results.finalByteCount,
    "budget_ref": "CLAUDE.md SS11 NFR-P2/P5 groundwork (cache-hit tile fetch must not re-render)",
    "note": "measures DocumentSession's TileCache/TileGrid against FakePDFEngine; real PDFium/on-screen frame-rate numbers are DocEngineHost's render-latency suite's concern"
]

let data = (try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])) ?? Data()
print(String(data: data, encoding: .utf8) ?? "{\"suite\":\"tile-scroll\",\"status\":\"fail\",\"reason\":\"utf8 encoding failed\"}")
exit(status == "pass" ? 0 : 1)
