import Foundation
import Platform

// Thin main (P1-12 skeleton, identical pattern to Services/DocEngineService
// from P0-05). What this can and can't prove right now:
//
// - CAN prove: Platform's XPC transport types compile and run correctly
//   inside a real, standalone, separately-launchable/killable executable
//   (not just inside the test process) - hence the in-process self-check
//   below, whose result is observable from outside via stdout.
// - CANNOT yet prove: a genuine cross-process connection *into* this
//   process from another one - that needs a real .xpc bundle target
//   (P0-07), same gap DocEngineService documents. See
//   docs/adr/ADR-002-xpc-transport-topology.md and the P0-05 task Journal
//   for the full empirical writeup.
//
// The registry/router/memory-governor logic this service will eventually
// host lives in Packages/InferenceHost (tested there); this executable
// stays a linkage/wiring proof only.
let listener = NSXPCListener.anonymous()
let host = XPCServiceHost<PingRequest, PingResponse>(
    listener: listener,
    route: "ping"
) { request in
    PingResponse(echoedNonce: request.nonce, serviceVersion: "InferenceService-skeleton-1.0")
}
host.resume()

let endpoint = listener.endpoint
let client = XPCClient<PingRequest, PingResponse>(route: "ping") {
    NSXPCConnection(listenerEndpoint: endpoint)
}

// See Services/DocEngineService/Sources/DocEngineService/main.swift for why
// this stays synchronous with an unstructured `Task` + `RunLoop.main.run()`
// rather than blocking the main thread on a semaphore.
let nonce = UUID().uuidString
Task {
    do {
        let response = try await client.send(PingRequest(nonce: nonce))
        if response.echoedNonce == nonce {
            print("InferenceService self-check: OK (\(response.serviceVersion))")
        } else {
            print("InferenceService self-check: FAILED (nonce mismatch)")
        }
    } catch {
        print("InferenceService self-check: FAILED (\(error))")
    }
    fflush(stdout)
}

RunLoop.main.run()
