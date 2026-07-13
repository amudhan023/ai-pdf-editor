import Foundation
import CryptoKit

// AuditLog: append-only, hash-chained local audit log
// Invariants: entry type has no value slot. No network I/O.

public enum AuditEventType: String, Codable, Sendable {
    case vaultRead
    case vaultWrite
    case ingestionCommitted
    case fillCommitted
    case networkEvent
    case authEvent
}

/// Closed set of metadata keys. Adding a key here is a deliberate,
/// reviewable decision — there is no free-form key, so a caller can never
/// invent a label to smuggle context under.
public enum AuditMetadataKey: String, Codable, Sendable, Hashable {
    case itemCount
    case durationMs
    case retryCount
    case resultHash
    case success
}

/// A hex-encoded SHA-256 digest, guaranteed well-formed. The *only* public
/// initializer validates the input, so there is no way to construct one
/// from arbitrary text without going through the check — unlike a bare
/// `case sha256(String)`, whose payload a caller could set to anything.
public struct SHA256Hex: Codable, Sendable, Equatable {
    public let hex: String

    public enum ValueError: Error {
        case invalidSHA256Format
    }

    public init(validating hex: String) throws {
        let isHex64 = hex.count == 64 && hex.allSatisfy(\.isHexDigit)
        guard isHex64 else { throw ValueError.invalidSHA256Format }
        self.hex = hex
    }
}

/// Closed set of metadata value shapes. There is deliberately no
/// free-string case: `.sha256` carries a `SHA256Hex`, not a `String`, so
/// document/vault content structurally cannot be encoded here — not merely
/// "shouldn't be" (CLAUDE.md §8.3, this task's acceptance criterion 2).
public enum AuditMetadataValue: Codable, Sendable, Equatable {
    case count(Int)
    case flag(Bool)
    case durationMs(Int)
    case sha256(SHA256Hex)
}

public struct AuditMetadataEntry: Codable, Sendable, Equatable {
    public let key: AuditMetadataKey
    public let value: AuditMetadataValue

    public init(key: AuditMetadataKey, value: AuditMetadataValue) {
        self.key = key
        self.value = value
    }
}

/// Any external event type (e.g. a future `Platform.DomainEvent`) can
/// conform to this to become appendable via `AuditLogStore.subscribe`,
/// without AuditLog importing the event's owning package — the adapter
/// that performs the actual conformance lives wherever both sides are
/// already in scope (CLAUDE.md §3.7: new cross-package dependencies need
/// their own ADR, so this package stays decoupled from any concrete bus).
public protocol AuditableEvent: Sendable {
    var auditEventType: AuditEventType { get }
    var auditFieldPath: String? { get }
    var auditTicketID: String? { get }
    var auditMetadata: [AuditMetadataEntry]? { get }
}

public struct AuditEntry: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AuditEventType
    public let fieldPath: String?
    public let ticketID: String?
    public let metadata: [AuditMetadataEntry]? // closed key/value shapes only — never a value
    public let prevHashHex: String?
    public let hashHex: String

    enum CodingKeys: String, CodingKey {
        case id, timestamp, eventType, fieldPath, ticketID, metadata, prevHashHex, hashHex
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: AuditEventType,
        fieldPath: String? = nil,
        ticketID: String? = nil,
        metadata: [AuditMetadataEntry]? = nil,
        prevHashHex: String?
    ) throws {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.fieldPath = fieldPath
        self.ticketID = ticketID
        // Sorted by key so the hash payload (and the on-disk encoding) is
        // deterministic regardless of the order the caller built the array in.
        self.metadata = metadata?.sorted { $0.key.rawValue < $1.key.rawValue }
        self.prevHashHex = prevHashHex

        let payload = try AuditEntry.hashPayload(
            id: id, timestamp: timestamp, eventType: eventType, fieldPath: fieldPath,
            ticketID: ticketID, metadata: self.metadata, prevHashHex: prevHashHex
        )
        self.hashHex = AuditEntry.sha256Hex(payload)
    }

    /// The exact bytes that get hashed, excluding `hashHex` itself. A
    /// `Codable` struct with sorted keys and a fixed date strategy (mirrors
    /// `PolicyKit.TicketClaims.canonicalPayload()`) rather than hand-rolled
    /// `JSONSerialization` over `[String: Any]` — deterministic regardless
    /// of dictionary iteration order or Foundation's default date encoding.
    private struct HashPayload: Encodable {
        let id: UUID
        let timestamp: Date
        let eventType: AuditEventType
        let fieldPath: String?
        let ticketID: String?
        let metadata: [AuditMetadataEntry]?
        let prevHashHex: String?
    }

    static func hashPayload(
        id: UUID, timestamp: Date, eventType: AuditEventType, fieldPath: String?,
        ticketID: String?, metadata: [AuditMetadataEntry]?, prevHashHex: String?
    ) throws -> Data {
        let payload = HashPayload(
            id: id, timestamp: timestamp, eventType: eventType, fieldPath: fieldPath,
            ticketID: ticketID, metadata: metadata, prevHashHex: prevHashHex
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(payload)
    }

    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Filter for `AuditLogStore.entries(matching:)`. All fields are AND'd;
/// `nil` means "don't filter on this dimension." This is the read path the
/// Privacy Dashboard (P3-03) is expected to drive.
public struct AuditEntryFilter: Sendable {
    public var eventTypes: Set<AuditEventType>?
    public var ticketID: String?
    public var fieldPathPrefix: String?
    public var from: Date?
    public var to: Date?

    public init(
        eventTypes: Set<AuditEventType>? = nil,
        ticketID: String? = nil,
        fieldPathPrefix: String? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) {
        self.eventTypes = eventTypes
        self.ticketID = ticketID
        self.fieldPathPrefix = fieldPathPrefix
        self.from = from
        self.to = to
    }

    func matches(_ entry: AuditEntry) -> Bool {
        if let eventTypes, !eventTypes.contains(entry.eventType) { return false }
        if let ticketID, entry.ticketID != ticketID { return false }
        if let fieldPathPrefix, !(entry.fieldPath?.hasPrefix(fieldPathPrefix) ?? false) { return false }
        if let from, entry.timestamp < from { return false }
        if let to, entry.timestamp > to { return false }
        return true
    }
}

public enum AuditLogError: Error {
    case ioError(Error)
    case verificationFailed
}
