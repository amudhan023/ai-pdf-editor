import DocEngineHost
import Foundation
import PDFEngineAPI

// Tile-render latency microbenchmark for Scripts/bench.sh's `render-latency`
// suite (P0-06 acceptance criterion: tile render p50 < 16ms at 1x for corpus
// text pages on M1). Renders a fixed-size tile from page 0 of every starter
// corpus fixture (Fixtures/pdf-corpus/starter, P0-08), repeated for a stable
// sample count, and reports percentiles as JSON on stdout - same shape as
// Platform's XPCLatencyBench for xpc-latency.

func findRepoRoot(from start: URL) -> URL? {
    var dir = start
    for _ in 0..<10 {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Fixtures/pdf-corpus/manifest.json").path) {
            return dir
        }
        dir = dir.deletingLastPathComponent()
    }
    return nil
}

guard let repoRoot = findRepoRoot(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) else {
    print("{\"suite\":\"render-latency\",\"status\":\"fail\",\"reason\":\"could not locate repo root / Fixtures/pdf-corpus from cwd\"}")
    exit(1)
}

let starterDir = repoRoot.appendingPathComponent("Fixtures/pdf-corpus/starter")
let fixtures = ["irs-fw9.pdf", "irs-fw4.pdf", "irs-f1040.pdf", "irs-f4506t.pdf", "uscis-i9.pdf"]
let iterationsPerFixture = 20

final class Results: @unchecked Sendable {
    var samplesMs: [Double] = []
    var isDone = false
    var failure: String?
}
let results = Results()

Task {
    let engine = PDFiumEngine()
    for name in fixtures {
        let url = starterDir.appendingPathComponent(name)
        do {
            let document = try await engine.open(url: url)
            let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 200, height: 200), scale: 1.0)

            // Warm up (first render pays page-load cost; exclude it).
            _ = try await engine.renderTile(of: document, request: request)

            for _ in 0..<iterationsPerFixture {
                let start = DispatchTime.now()
                _ = try await engine.renderTile(of: document, request: request)
                let end = DispatchTime.now()
                results.samplesMs.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            }
            try await engine.close(document)
        } catch {
            results.failure = "fixture \(name) failed: \(error)"
            break
        }
    }
    results.isDone = true
}
while !results.isDone {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
}

if let failure = results.failure {
    let payload: [String: Any] = ["suite": "render-latency", "status": "fail", "reason": failure]
    let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    print(String(data: data, encoding: .utf8) ?? "{\"suite\":\"render-latency\",\"status\":\"fail\"}")
    exit(1)
}

let sorted = results.samplesMs.sorted()
func percentile(_ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let idx = min(sorted.count - 1, max(0, Int((p / 100) * Double(sorted.count))))
    return sorted[idx]
}

let budgetMs = 16.0
let p50 = percentile(50)
let status = p50 < budgetMs ? "pass" : "fail"

let result: [String: Any] = [
    "suite": "render-latency",
    "status": status,
    "iterations": sorted.count,
    "p50_ms": (p50 * 1000).rounded() / 1000,
    "p90_ms": (percentile(90) * 1000).rounded() / 1000,
    "max_ms": (sorted.last ?? 0),
    "budget_ms": budgetMs,
    "budget_ref": "CLAUDE.md SS11 NFR-P2 groundwork (tile render p50 < 16ms at 1x)",
    "fixtures": fixtures
]

let data = (try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])) ?? Data()
print(String(data: data, encoding: .utf8) ?? "{\"suite\":\"render-latency\",\"status\":\"fail\",\"reason\":\"utf8 encoding failed\"}")
exit(status == "pass" ? 0 : 1)
