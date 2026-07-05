import Foundation
import Platform

// Thin main (P0-05 skeleton). What this can and can't prove right now:
//
// - CAN prove: Platform's XPC transport types compile and run correctly
//   inside a real, standalone, separately-launchable/killable executable
//   (not just inside the test process) - hence the in-process self-check
//   below, whose result is observable from outside via stdout.
// - CANNOT yet prove: a genuine cross-process connection *into* this
//   process from another one. `NSXPCListenerEndpoint` can only be encoded
//   by `NSXPCCoder` (confirmed empirically: NSKeyedArchiver throws
//   "may only be encoded by an NSXPCCoder"), and an ad-hoc
//   `NSXPCListener(machServiceName:)` between two independently-spawned,
//   non-launchd-registered processes does not connect either (confirmed
//   empirically: the connecting side crashes/hangs, no successful
//   round-trip). Real cross-process XPC on macOS requires either a
//   launchd-registered Mach service or - the actual production path here -
//   proper `.xpc` bundle embedding in the app target, where `xpcproxy`
//   handles registration by bundle identifier. That's P0-07's job, not
//   achievable from a bare SwiftPM executable. See the P0-05 task Journal
//   for the full writeup; `XPCTransportTests` (Platform package) covers
//   the transport contract itself via same-process anonymous listeners,
//   which *is* genuine XPC IPC, just not a different OS process.
let listener = NSXPCListener.anonymous()
let host = XPCServiceHost<PingRequest, PingResponse>(
    listener: listener,
    route: "ping"
) { request in
    PingResponse(echoedNonce: request.nonce, serviceVersion: "DocEngineService-skeleton-1.0")
}
host.resume()

let endpoint = listener.endpoint
let client = XPCClient<PingRequest, PingResponse>(route: "ping") {
    NSXPCConnection(listenerEndpoint: endpoint)
}

// Top-level `main.swift` code stays synchronous (not `async`) so
// `RunLoop.main.run()` below can actually block forever - an async main
// context can't call it (unavailable from async contexts). The self-check
// runs concurrently in an unstructured `Task`; blocking the main thread on
// a semaphore *before* entering the run loop was tried and doesn't work -
// the Task never got scheduled (Dispatch's default executor needs the
// main thread free or pumping its run loop, not parked on a semaphore).
// Just enter the run loop immediately instead and let the Task print
// whenever it completes.
let nonce = UUID().uuidString
Task {
    do {
        let response = try await client.send(PingRequest(nonce: nonce))
        if response.echoedNonce == nonce {
            print("DocEngineService self-check: OK (\(response.serviceVersion))")
        } else {
            print("DocEngineService self-check: FAILED (nonce mismatch)")
        }
    } catch {
        print("DocEngineService self-check: FAILED (\(error))")
    }
    fflush(stdout)
}

RunLoop.main.run()
