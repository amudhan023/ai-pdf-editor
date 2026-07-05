// GENERATED FILE - DO NOT EDIT.
// Source: Schemas/xpc-dtos.yml
// Regenerate: Scripts/codegen.sh

import Foundation

public enum XPCInterfaceVersion {
    public static let current = "v1"
}

public struct PingRequest: Codable, Sendable, Equatable {
    public let nonce: String

    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct PingResponse: Codable, Sendable, Equatable {
    public let echoedNonce: String
    public let serviceVersion: String

    public init(echoedNonce: String, serviceVersion: String) {
        self.echoedNonce = echoedNonce
        self.serviceVersion = serviceVersion
    }
}
