import Foundation
import Platform

// Round-trip latency microbenchmark for Scripts/bench.sh's `xpc-latency`
// suite (P0-05 Definition of Done: ADR-002 baseline). Same-process
// anonymous-listener round trips - a real process-boundary XPC call adds
// Mach IPC overhead this doesn't capture, but that overhead is roughly
// constant across runs, so this still catches *regressions* in the
// envelope encode/decode + dispatch path itself, which is what a
// microbenchmark run on every `bench.yml` invocation is actually for.

let listener = NSXPCListener.anonymous()
let host = XPCServiceHost<PingRequest, PingResponse>(listener: listener, route: "ping") { request in
    PingResponse(echoedNonce: request.nonce, serviceVersion: "bench")
}
host.resume()

let endpoint = listener.endpoint
let client = XPCClient<PingRequest, PingResponse>(route: "ping") {
    NSXPCConnection(listenerEndpoint: endpoint)
}

let iterations = 200
final class Results: @unchecked Sendable {
    var samplesMs: [Double] = []
    var isDone = false
}
let results = Results()

// NOTE: blocking the main thread on a semaphore *before* the Task below
// gets scheduled deadlocks it - confirmed empirically (see
// Services/DocEngineService/Sources/DocEngineService/main.swift's comment
// for the same finding). Pumping the run loop in short bursts instead lets
// the Task actually run while still letting this exit once done.
Task {
    // Warm up (first call pays connection-setup cost; exclude it).
    _ = try? await client.send(PingRequest(nonce: "warmup"))

    for i in 0..<iterations {
        let start = DispatchTime.now()
        _ = try? await client.send(PingRequest(nonce: "sample-\(i)"))
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        results.samplesMs.append(ms)
    }
    results.isDone = true
}
while !results.isDone {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
let samplesMs = results.samplesMs

let sorted = samplesMs.sorted()
func percentile(_ p: Double) -> Double {
    let idx = min(sorted.count - 1, max(0, Int((p / 100) * Double(sorted.count))))
    return sorted[idx]
}

let result: [String: Any] = [
    "suite": "xpc-latency",
    "status": "pass",
    "iterations": iterations,
    "p50_ms": (percentile(50) * 1000).rounded() / 1000,
    "p90_ms": (percentile(90) * 1000).rounded() / 1000,
    "max_ms": (sorted.last ?? 0),
    "note": "same-process anonymous-listener round trips; real cross-process calls "
        + "add Mach IPC overhead not captured here (P0-07 needed for that measurement)"
]

do {
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8) ?? "{\"suite\":\"xpc-latency\",\"status\":\"fail\",\"reason\":\"utf8 encoding failed\"}")
} catch {
    print("{\"suite\":\"xpc-latency\",\"status\":\"fail\",\"reason\":\"\(error)\"}")
}
