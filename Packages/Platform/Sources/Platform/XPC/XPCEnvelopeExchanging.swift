import Foundation
import IOSurface

/// The one `@objc` protocol every XPC connection in this app speaks.
/// `exchange` carries every Codable DTO pair (see `XPCEnvelope`);
/// `sendSurface` is the separate, zero-copy path for bitmap payloads
/// (ARCHITECTURE.md's page-tile rendering) - an `IOSurface` is real shared
/// memory across the process boundary, not something to JSON-encode.
@objc public protocol XPCEnvelopeExchanging: NSObjectProtocol {
    func exchange(_ requestEnvelopeData: Data, reply: @escaping (Data) -> Void)
    func sendSurface(_ surface: IOSurface, tag: String, reply: @escaping (Bool, String?) -> Void)
}
