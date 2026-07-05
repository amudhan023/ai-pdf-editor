import Foundation
import IOSurface

/// Generic, typed listener side of one XPC service. Wraps an `NSXPCListener`
/// (anonymous for in-process/tests, or a real named service in a shipped
/// `.xpc` bundle) and dispatches decoded requests to `handler`.
public final class XPCServiceHost<Request: Codable & Sendable, Response: Codable & Sendable>: @unchecked Sendable {
    public typealias Handler = @Sendable (Request) async throws -> Response
    public typealias SurfaceHandler = @Sendable (IOSurface, String) -> Bool

    private let listener: NSXPCListener
    private let route: String
    private let interfaceVersion: String
    private let handler: Handler
    private let surfaceHandler: SurfaceHandler?
    private var delegate: ListenerDelegate?

    public init(
        listener: NSXPCListener,
        route: String,
        interfaceVersion: String = XPCInterfaceVersion.current,
        handler: @escaping Handler,
        surfaceHandler: SurfaceHandler? = nil
    ) {
        self.listener = listener
        self.route = route
        self.interfaceVersion = interfaceVersion
        self.handler = handler
        self.surfaceHandler = surfaceHandler
    }

    public func resume() {
        let exported = ExportedExchanger(
            route: route,
            interfaceVersion: interfaceVersion,
            handler: handler,
            surfaceHandler: surfaceHandler
        )
        let delegate = ListenerDelegate(exportedObject: exported)
        self.delegate = delegate
        listener.delegate = delegate
        listener.resume()
    }
}

/// `NSXPCListener`'s delegate must be a plain `NSObject`; kept separate from
/// the generic `XPCServiceHost` (generic classes can't be `@objc` themselves).
private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let exportedObject: NSObject

    init(exportedObject: NSObject) {
        self.exportedObject = exportedObject
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCEnvelopeExchanging.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

/// The actual `@objc`-visible exported object. Non-generic (unlike
/// `XPCServiceHost`) because `@objc` protocol conformance on a generic
/// class only works if the generic parameters never appear in an `@objc`
/// method's signature - true here (everything is `Data`/`IOSurface`), but
/// keeping the exported type itself non-generic sidesteps the question
/// entirely and matches how `NSXPCListenerDelegate` expects a concrete
/// `NSObject`.
private final class ExportedExchanger: NSObject, XPCEnvelopeExchanging, @unchecked Sendable {
    private let route: String
    private let interfaceVersion: String
    private let handleRequest: (Data) async -> Data
    private let surfaceHandler: XPCServiceHost<Data, Data>.SurfaceHandler?

    init<Request: Codable & Sendable, Response: Codable & Sendable>(
        route: String,
        interfaceVersion: String,
        handler: @escaping @Sendable (Request) async throws -> Response,
        surfaceHandler: (@Sendable (IOSurface, String) -> Bool)?
    ) {
        self.route = route
        self.interfaceVersion = interfaceVersion
        self.surfaceHandler = surfaceHandler
        self.handleRequest = { requestEnvelopeData in
            do {
                let envelope = try JSONDecoder().decode(XPCEnvelope.self, from: requestEnvelopeData)
                guard envelope.interfaceVersion == interfaceVersion else {
                    // Framed from the *client's* perspective (local = the
                    // version the client sent, remote = the host's own),
                    // since this error travels back to the client and is
                    // interpreted there - not from the host's own frame of
                    // reference, which would read backwards to the caller.
                    return Self.encodeError(
                        .versionMismatch(local: envelope.interfaceVersion, remote: interfaceVersion),
                        interfaceVersion: interfaceVersion
                    )
                }
                guard envelope.route == route else {
                    return Self.encodeError(
                        .decodingFailed("unexpected route '\(envelope.route)', expected '\(route)'"),
                        interfaceVersion: interfaceVersion
                    )
                }
                let request = try JSONDecoder().decode(Request.self, from: envelope.payload)
                let response = try await handler(request)
                let payload = try JSONEncoder().encode(response)
                let responseEnvelope = XPCResponseEnvelope(interfaceVersion: interfaceVersion, payload: payload, error: nil)
                return try JSONEncoder().encode(responseEnvelope)
            } catch let error as XPCTransportError {
                return Self.encodeError(error, interfaceVersion: interfaceVersion)
            } catch {
                return Self.encodeError(.remote("\(error)"), interfaceVersion: interfaceVersion)
            }
        }
        super.init()
    }

    private static func encodeError(_ error: XPCTransportError, interfaceVersion: String) -> Data {
        let responseEnvelope = XPCResponseEnvelope(interfaceVersion: interfaceVersion, payload: nil, error: error)
        return (try? JSONEncoder().encode(responseEnvelope)) ?? Data()
    }

    func exchange(_ requestEnvelopeData: Data, reply: @escaping (Data) -> Void) {
        // `reply` is an Objective-C block handed to us by NSXPCConnection's
        // runtime machinery - safe to call from any thread by design (that's
        // the whole point of an XPC reply block). Boxing it in an explicit
        // `@unchecked Sendable` type (rather than a `nonisolated(unsafe) let`
        // capture) is what actually portable across Swift 6.1-6.3 toolchains
        // - the compiler version this repo's CI runner ships (6.1.2) rejects
        // the `nonisolated(unsafe)` local-binding form here even though a
        // newer local toolchain accepts it.
        let box = ReplyBox(reply)
        Task {
            let responseData = await handleRequest(requestEnvelopeData)
            box.call(responseData)
        }
    }

    func sendSurface(_ surface: IOSurface, tag: String, reply: @escaping (Bool, String?) -> Void) {
        guard let surfaceHandler else {
            reply(false, "no surface handler registered for route '\(route)'")
            return
        }
        let ok = surfaceHandler(surface, tag)
        reply(ok, ok ? nil : "surfaceHandler returned false")
    }
}

/// Wraps an XPC reply block so it can cross into a `Task {}` without
/// tripping Swift 6 concurrency's "sending" checks - see the comment at
/// `ExportedExchanger.exchange`'s call site for why this exists instead of
/// a `nonisolated(unsafe) let` capture. `internal` (not `private`) so
/// test-only exported objects (e.g. `XPCCrashRecoveryIntegrationTests`)
/// can reuse it via `@testable import` instead of duplicating this pattern.
final class ReplyBox: @unchecked Sendable {
    private let reply: (Data) -> Void
    init(_ reply: @escaping (Data) -> Void) { self.reply = reply }
    func call(_ data: Data) { reply(data) }
}
