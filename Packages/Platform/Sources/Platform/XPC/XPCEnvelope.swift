import Foundation

/// Wire shape for every XPC call: a route name (which DTO pair this is),
/// the interface version the sender is speaking, and the JSON-encoded
/// request/response payload. One generic `@objc` method (`exchange`)
/// carries every route - see ADR-002 for why (avoids a new `@objc`
/// protocol per DTO type, which is the alternative NSXPCConnection would
/// otherwise force).
public struct XPCEnvelope: Codable, Sendable, Equatable {
    public let route: String
    public let interfaceVersion: String
    public let payload: Data

    public init(route: String, interfaceVersion: String, payload: Data) {
        self.route = route
        self.interfaceVersion = interfaceVersion
        self.payload = payload
    }
}

/// Response side of the envelope: exactly one of `payload`/`error` is
/// non-nil. Encoded even for the error case so `exchange`'s `reply` closure
/// never needs an `Optional<Data>` (NSXPCConnection reply blocks are
/// simplest when their parameters are non-optional wire types).
public struct XPCResponseEnvelope: Codable, Sendable, Equatable {
    public let interfaceVersion: String
    public let payload: Data?
    public let error: XPCTransportError?

    public init(interfaceVersion: String, payload: Data?, error: XPCTransportError?) {
        self.interfaceVersion = interfaceVersion
        self.payload = payload
        self.error = error
    }
}
