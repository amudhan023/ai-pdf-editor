import Foundation
import IOSurface

/// Generic, typed async client over one `NSXPCConnection`. One instance
/// per (Request, Response) DTO pair / route - see `Services/DocEngineService`
/// for the shape a real consumer uses.
///
/// Auto-reconnect policy (P0-05 requirement): a crashed/invalidated
/// connection is dropped immediately so the *next* `send` call builds a
/// fresh one - the in-flight call still fails with `.serviceCrashed`
/// rather than silently retrying, since only the caller knows whether a
/// retry is safe (idempotency is call-specific, not this layer's business).
public final class XPCClient<Request: Codable & Sendable, Response: Codable & Sendable>: @unchecked Sendable {
    public typealias ConnectionFactory = @Sendable () -> NSXPCConnection

    private let route: String
    private let interfaceVersion: String
    private let makeConnection: ConnectionFactory
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    public init(
        route: String,
        interfaceVersion: String = XPCInterfaceVersion.current,
        makeConnection: @escaping ConnectionFactory
    ) {
        self.route = route
        self.interfaceVersion = interfaceVersion
        self.makeConnection = makeConnection
    }

    private func currentConnection() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }
        if let connection { return connection }
        let newConnection = makeConnection()
        newConnection.remoteObjectInterface = NSXPCInterface(with: XPCEnvelopeExchanging.self)
        newConnection.invalidationHandler = { [weak self] in self?.dropConnection() }
        newConnection.interruptionHandler = { [weak self] in self?.dropConnection() }
        newConnection.resume()
        connection = newConnection
        return newConnection
    }

    private func dropConnection() {
        lock.lock()
        connection = nil
        lock.unlock()
    }

    public func send(_ request: Request, timeout: TimeInterval = 5.0) async throws -> Response {
        let conn = currentConnection()
        let requestPayload = try JSONEncoder().encode(request)
        let envelope = XPCEnvelope(route: route, interfaceVersion: interfaceVersion, payload: requestPayload)
        let envelopeData = try JSONEncoder().encode(envelope)
        let expectedVersion = interfaceVersion

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Response, Error>) in
            let box = ResumeOnce(continuation)

            let proxy = conn.remoteObjectProxyWithErrorHandler { [weak self] _ in
                self?.dropConnection()
                box.resume(throwing: XPCTransportError.serviceCrashed)
            } as? XPCEnvelopeExchanging

            guard let proxy else {
                box.resume(throwing: XPCTransportError.decodingFailed("remote proxy does not conform to XPCEnvelopeExchanging"))
                return
            }

            let timeoutWork = DispatchWorkItem { box.resume(throwing: XPCTransportError.timedOut) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            proxy.exchange(envelopeData) { responseData in
                timeoutWork.cancel()
                do {
                    let responseEnvelope = try JSONDecoder().decode(XPCResponseEnvelope.self, from: responseData)
                    if let remoteError = responseEnvelope.error {
                        box.resume(throwing: remoteError)
                        return
                    }
                    guard let payload = responseEnvelope.payload else {
                        box.resume(throwing: XPCTransportError.decodingFailed("response envelope had neither payload nor error"))
                        return
                    }
                    guard responseEnvelope.interfaceVersion == expectedVersion else {
                        box.resume(throwing: XPCTransportError.versionMismatch(
                            local: expectedVersion, remote: responseEnvelope.interfaceVersion
                        ))
                        return
                    }
                    let response = try JSONDecoder().decode(Response.self, from: payload)
                    box.resume(returning: response)
                } catch {
                    box.resume(throwing: XPCTransportError.decodingFailed("\(error)"))
                }
            }
        }
    }

    /// Sends a raw `IOSurface` over the same connection this client uses
    /// for typed DTO calls - the zero-copy bitmap path (P0-05 requirement).
    public func sendSurface(_ surface: IOSurface, tag: String, timeout: TimeInterval = 5.0) async throws {
        let conn = currentConnection()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = ResumeOnce(continuation)

            let proxy = conn.remoteObjectProxyWithErrorHandler { [weak self] _ in
                self?.dropConnection()
                box.resume(throwing: XPCTransportError.serviceCrashed)
            } as? XPCEnvelopeExchanging

            guard let proxy else {
                box.resume(throwing: XPCTransportError.decodingFailed("remote proxy does not conform to XPCEnvelopeExchanging"))
                return
            }

            let timeoutWork = DispatchWorkItem { box.resume(throwing: XPCTransportError.timedOut) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            proxy.sendSurface(surface, tag: tag) { ok, reason in
                timeoutWork.cancel()
                if ok {
                    box.resume(returning: ())
                } else {
                    box.resume(throwing: XPCTransportError.remote(reason ?? "sendSurface failed"))
                }
            }
        }
    }
}

/// Guards a `CheckedContinuation` against being resumed twice - both the
/// connection's error handler and the reply closure can fire for the same
/// in-flight call (e.g. a crash right as a reply was already in transit),
/// and `CheckedContinuation` traps on a double-resume.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<T, Error>

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(throwing: error)
    }
}
