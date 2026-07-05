import Foundation

/// Typed transport failures. `Codable` because a service-side failure
/// (e.g. a version mismatch it detected) travels back inside an
/// `XPCResponseEnvelope`, not as a raw Swift `Error` (which isn't
/// transferable across the XPC boundary). `.serviceCrashed` is the one
/// case a client synthesizes locally, from `NSXPCConnection`'s
/// interruption/invalidation handlers, since a crashed process obviously
/// can't encode and send its own error.
public enum XPCTransportError: Error, Codable, Sendable, Equatable, CustomStringConvertible {
    case versionMismatch(local: String, remote: String)
    case serviceCrashed
    case timedOut
    case decodingFailed(String)
    case remote(String)

    public var description: String {
        switch self {
        case let .versionMismatch(local, remote):
            return "XPC interface version mismatch (local: \(local), remote: \(remote))"
        case .serviceCrashed:
            return "XPC service crashed or connection invalidated mid-call"
        case .timedOut:
            return "XPC call timed out"
        case let .decodingFailed(reason):
            return "XPC envelope decode/encode failed: \(reason)"
        case let .remote(reason):
            return "XPC remote handler threw: \(reason)"
        }
    }
}
