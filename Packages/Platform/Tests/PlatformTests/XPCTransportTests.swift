import XCTest
import IOSurface
@testable import Platform

/// Same-process round-trips via `NSXPCListener.anonymous()` - a real XPC
/// listener/connection pair (genuine IPC machinery, genuine serialization),
/// just not a separate OS process. Cross-process behavior (crash recovery)
/// is `XPCIntegrationTests`' job, not this file's - see that class for why
/// the split exists (CLAUDE.md §9's integration tier, P0-15).
final class XPCTransportTests: XCTestCase {
    // NSXPCListener.delegate is `weak` - the delegate (retained by
    // XPCServiceHost) must outlive the listener or incoming connections
    // silently get no delegate to accept them. Real usage keeps the host
    // alive as a top-level value in a service's main(); tests must do the
    // same explicitly rather than let a local `host` fall out of scope.
    private var retainedHosts: [Any] = []

    private func makeConnectedPair(
        route: String = "ping",
        interfaceVersion: String = XPCInterfaceVersion.current,
        handler: @escaping @Sendable (PingRequest) async throws -> PingResponse
    ) -> (client: XPCClient<PingRequest, PingResponse>, listener: NSXPCListener) {
        let listener = NSXPCListener.anonymous()
        let host = XPCServiceHost<PingRequest, PingResponse>(
            listener: listener,
            route: route,
            interfaceVersion: interfaceVersion,
            handler: handler,
            surfaceHandler: { surface, tag in
                // Proves the client's raw bytes made it across as real
                // shared memory: flips every byte in the first row.
                guard tag == "flip" else { return false }
                IOSurfaceLock(surface, [], nil)
                defer { IOSurfaceUnlock(surface, [], nil) }
                guard let base = IOSurfaceGetBaseAddress(surface) as UnsafeMutableRawPointer? else { return false }
                let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
                let row = base.assumingMemoryBound(to: UInt8.self)
                for byteIndex in 0..<min(bytesPerRow, 16) {
                    row[byteIndex] = ~row[byteIndex]
                }
                return true
            }
        )
        host.resume()
        retainedHosts.append(host)

        let endpoint = listener.endpoint
        let client = XPCClient<PingRequest, PingResponse>(route: route, interfaceVersion: interfaceVersion) {
            NSXPCConnection(listenerEndpoint: endpoint)
        }
        return (client, listener)
    }

    func testPingRoundTrip() async throws {
        let (client, _) = makeConnectedPair { request in
            PingResponse(echoedNonce: request.nonce, serviceVersion: "test-1.0")
        }
        let response = try await client.send(PingRequest(nonce: "abc123"))
        XCTAssertEqual(response.echoedNonce, "abc123")
        XCTAssertEqual(response.serviceVersion, "test-1.0")
    }

    func testVersionMismatchIsTypedError() async throws {
        let (client, _) = makeConnectedPair(interfaceVersion: "v1") { request in
            PingResponse(echoedNonce: request.nonce, serviceVersion: "test-1.0")
        }
        // Rebuild a client that claims a different local version than the
        // host it's actually talking to, to exercise the negotiation path.
        let listener = NSXPCListener.anonymous()
        let host = XPCServiceHost<PingRequest, PingResponse>(
            listener: listener, route: "ping", interfaceVersion: "v2"
        ) { request in
            PingResponse(echoedNonce: request.nonce, serviceVersion: "test-1.0")
        }
        host.resume()
        retainedHosts.append(host)
        let endpoint = listener.endpoint
        let mismatchedClient = XPCClient<PingRequest, PingResponse>(route: "ping", interfaceVersion: "v1") {
            NSXPCConnection(listenerEndpoint: endpoint)
        }

        do {
            _ = try await mismatchedClient.send(PingRequest(nonce: "x"))
            XCTFail("expected a versionMismatch error")
        } catch let error as XPCTransportError {
            guard case let .versionMismatch(local, remote) = error else {
                XCTFail("expected .versionMismatch, got \(error)")
                return
            }
            XCTAssertEqual(local, "v1")
            XCTAssertEqual(remote, "v2")
        }
        _ = client // silence unused-variable warning from the first pair
    }

    func testRemoteThrowIsSurfacedAsTypedError() async throws {
        struct HandlerFailure: Error {}
        let (client, _) = makeConnectedPair { _ in
            throw HandlerFailure()
        }
        do {
            _ = try await client.send(PingRequest(nonce: "x"))
            XCTFail("expected a remote error")
        } catch let error as XPCTransportError {
            guard case .remote = error else {
                XCTFail("expected .remote, got \(error)")
                return
            }
        }
    }

    func testTimeoutFiresWhenHandlerNeverReplies() async throws {
        let listener = NSXPCListener.anonymous()
        let host = XPCServiceHost<PingRequest, PingResponse>(listener: listener, route: "ping") { _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return PingResponse(echoedNonce: "late", serviceVersion: "test")
        }
        host.resume()
        retainedHosts.append(host)
        let endpoint = listener.endpoint
        let client = XPCClient<PingRequest, PingResponse>(route: "ping") {
            NSXPCConnection(listenerEndpoint: endpoint)
        }

        do {
            _ = try await client.send(PingRequest(nonce: "x"), timeout: 0.1)
            XCTFail("expected a timedOut error")
        } catch let error as XPCTransportError {
            XCTAssertEqual(error, .timedOut)
        }
    }

    func testIOSurfaceRoundTripIsRealSharedMemory() async throws {
        let (client, _) = makeConnectedPair { request in
            PingResponse(echoedNonce: request.nonce, serviceVersion: "test")
        }

        let properties: [IOSurfacePropertyKey: Any] = [
            .width: 4, .height: 4, .bytesPerElement: 1, .pixelFormat: 0x4C303030 // 'L000' (8-bit grayscale-ish)
        ]
        guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
            XCTFail("failed to create test IOSurface")
            return
        }

        IOSurfaceLock(surface, [], nil)
        let base = IOSurfaceGetBaseAddress(surface).assumingMemoryBound(to: UInt8.self)
        for byteIndex in 0..<4 { base[byteIndex] = UInt8(byteIndex) }
        IOSurfaceUnlock(surface, [], nil)

        try await client.sendSurface(surface, tag: "flip")

        IOSurfaceLock(surface, [.readOnly], nil)
        let after = IOSurfaceGetBaseAddress(surface).assumingMemoryBound(to: UInt8.self)
        let flipped = (0..<4).map { after[$0] }
        IOSurfaceUnlock(surface, [.readOnly], nil)

        // The service flipped bytes in place on the *same* underlying
        // surface memory - if this were JSON/Data copying instead of a
        // real IOSurface handoff, the client's local surface would be
        // untouched by the service's mutation.
        XCTAssertEqual(flipped, [0, 1, 2, 3].map { ~UInt8($0) })
    }
}
