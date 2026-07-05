import XCTest
import Foundation
import IOSurface
@testable import Platform

/// P0-05's "kills the service mid-call and receives typed failure +
/// successful retry" acceptance criterion - via genuine `NSXPCConnection`
/// invalidation rather than a literally separate OS process.
///
/// Why not a real separate process: confirmed empirically (see the P0-05
/// task Journal) that `NSXPCListenerEndpoint` can only be encoded by
/// `NSXPCCoder` (NSKeyedArchiver refuses it), and an ad-hoc
/// `NSXPCListener(machServiceName:)` between two independently-spawned,
/// non-launchd-registered processes does not connect. Genuine cross-process
/// XPC on macOS needs either a launchd-registered Mach service or a real
/// `.xpc` bundle embedded in an app target (P0-07) - not achievable from a
/// bare SwiftPM package. `Services/DocEngineService` is a real, standalone,
/// separately-launchable/killable executable proving the transport links
/// and runs outside the test process (its own self-check), but this class
/// is where the crash+reconnect *contract* is actually verified: invalidating
/// a live `NSXPCConnection` produces the identical client-observable
/// signal (interruption/invalidation handler firing) that a real process
/// death does - `XPCClient` cannot tell the difference, which is exactly
/// the point of testing it this way.
final class XPCCrashRecoveryIntegrationTests: XCTestCase {
    /// Exported object for a listener that "crashes" (invalidates its own
    /// connection instead of replying) when it sees a sentinel nonce -
    /// this class exists only for this test, not shipped as a public API,
    /// since production services have no legitimate reason to crash
    /// themselves on request.
    private final class CrashOnDemandExchanger: NSObject, XPCEnvelopeExchanging, @unchecked Sendable {
        private let lock = NSLock()
        private var connection: NSXPCConnection?

        func attach(_ connection: NSXPCConnection) {
            lock.withLock { self.connection = connection }
        }

        func exchange(_ requestEnvelopeData: Data, reply: @escaping (Data) -> Void) {
            // `nonisolated(unsafe) let reply = reply` compiles on newer
            // toolchains but is rejected by this repo's CI runner (Swift
            // 6.1.2) - an explicit `@unchecked Sendable` box is portable
            // across both (see XPCServiceHost.swift's `ReplyBox`, same fix).
            let box = ReplyBox(reply)
            Task {
                guard
                    let envelope = try? JSONDecoder().decode(XPCEnvelope.self, from: requestEnvelopeData),
                    let request = try? JSONDecoder().decode(PingRequest.self, from: envelope.payload)
                else {
                    box.call(Data())
                    return
                }
                if request.nonce == "CRASH_ME" {
                    let connection = self.lock.withLock { self.connection }
                    // Never call `reply` - a real crash doesn't get to
                    // reply either. Invalidating is what actually severs
                    // the connection and fires the client's handlers.
                    connection?.invalidate()
                    return
                }
                let response = PingResponse(echoedNonce: request.nonce, serviceVersion: "crash-recovery-test")
                guard let payload = try? JSONEncoder().encode(response) else {
                    box.call(Data())
                    return
                }
                let responseEnvelope = XPCResponseEnvelope(
                    interfaceVersion: envelope.interfaceVersion, payload: payload, error: nil
                )
                box.call((try? JSONEncoder().encode(responseEnvelope)) ?? Data())
            }
        }

        func sendSurface(_ surface: IOSurface, tag: String, reply: @escaping (Bool, String?) -> Void) {
            reply(false, "not supported by CrashOnDemandExchanger")
        }
    }

    private final class CrashOnDemandDelegate: NSObject, NSXPCListenerDelegate {
        let exchanger = CrashOnDemandExchanger()

        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            newConnection.exportedInterface = NSXPCInterface(with: XPCEnvelopeExchanging.self)
            newConnection.exportedObject = exchanger
            exchanger.attach(newConnection)
            newConnection.resume()
            return true
        }
    }

    // Retains delegates for the test's lifetime - NSXPCListener.delegate is
    // `weak` (see the same note in XPCTransportTests).
    private var retainedDelegates: [Any] = []

    func testCrashMidCallProducesTypedFailureThenSuccessfulRetry() async throws {
        let listener = NSXPCListener.anonymous()
        let delegate = CrashOnDemandDelegate()
        listener.delegate = delegate
        listener.resume()
        retainedDelegates.append(delegate)

        let endpoint = listener.endpoint
        let client = XPCClient<PingRequest, PingResponse>(route: "ping") {
            NSXPCConnection(listenerEndpoint: endpoint)
        }

        do {
            _ = try await client.send(PingRequest(nonce: "CRASH_ME"), timeout: 2.0)
            XCTFail("expected the crashed call to throw .serviceCrashed")
        } catch let error as XPCTransportError {
            XCTAssertEqual(error, .serviceCrashed)
        }

        // Same client instance, same route - the auto-reconnect policy
        // means this call builds a fresh NSXPCConnection rather than
        // reusing the now-dead one, and succeeds.
        let response = try await client.send(PingRequest(nonce: "after-crash"))
        XCTAssertEqual(response.echoedNonce, "after-crash")
    }
}
