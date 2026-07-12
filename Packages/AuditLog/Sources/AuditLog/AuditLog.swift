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

public struct AuditEntry: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AuditEventType
    public let fieldPath: String?
    public let ticketID: String?
    public let metadata: [String: String]? // only non-sensitive metadata (no values)
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
        metadata: [String: String]? = nil,
        prevHashHex: String?
    ) throws {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.fieldPath = fieldPath
        self.ticketID = ticketID
        self.metadata = metadata
        self.prevHashHex = prevHashHex

        let payload = try AuditEntry.hashPayload(
            id: id, timestamp: timestamp, eventType: eventType, fieldPath: fieldPath,
            ticketID: ticketID, metadata: metadata, prevHashHex: prevHashHex
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
        let metadata: [String: String]?
        let prevHashHex: String?
    }

    static func hashPayload(
        id: UUID, timestamp: Date, eventType: AuditEventType, fieldPath: String?,
        ticketID: String?, metadata: [String: String]?, prevHashHex: String?
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

public enum AuditLogError: Error {
    case ioError(Error)
    case verificationFailed
}

/// Append-only, hash-chained audit log (CLAUDE.md §7.9, §16 — audit entries
/// carry IDs/paths/hashes, never values). An `actor` so every append is
/// naturally serialized without a hand-rolled `DispatchQueue` (CLAUDE.md §4:
/// "no `DispatchQueue` in new code without justification").
///
/// `cachedLastHash` is the point of this rewrite: the prior version called
/// `lastHash()` — which decodes every entry in every segment — on every
/// single `append`, making the log O(n^2) over its own lifetime. This
/// records the tail hash in memory at init (reading only the newest
/// non-empty segment's last line, not the whole log) and updates it after
/// each write, making `append` O(1) amortized in the common case.
public actor AuditLogStore {
    private let directory: URL
    // `.secondsSince1970` (not `.iso8601`, which truncates to whole
    // seconds): must round-trip losslessly, since `verifyChain` recomputes
    // each entry's hash from its *decoded* fields and compares against the
    // hash computed from the original in-memory `Date` — any precision lost
    // between encode and decode would make every entry fail verification
    // after being read back. Matches `hashPayload`'s own date strategy
    // below and `PolicyKit.TicketClaims`'s precedent for the same reason.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    private var currentHandle: FileHandle
    private var currentSegmentIndex: Int
    private var currentSegmentSize: UInt64 = 0
    private let maxSegmentBytes: UInt64
    private var cachedLastHash: String?

    public init(directory: URL, maxSegmentBytes: UInt64 = 64 * 1024) throws {
        self.directory = directory
        self.maxSegmentBytes = maxSegmentBytes
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let existing = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "seg" }
        let indices = existing.compactMap { Int($0.deletingPathExtension().lastPathComponent) }
        self.currentSegmentIndex = indices.max() ?? 0

        let segmentURL = directory.appendingPathComponent("\(self.currentSegmentIndex).seg")
        if FileManager.default.fileExists(atPath: segmentURL.path) {
            self.currentHandle = try FileHandle(forUpdating: segmentURL)
            self.currentSegmentSize = try self.currentHandle.seekToEnd()
        } else {
            FileManager.default.createFile(atPath: segmentURL.path, contents: nil)
            self.currentHandle = try FileHandle(forUpdating: segmentURL)
            self.currentSegmentSize = 0
        }

        self.cachedLastHash = try Self.lastHashHexSearchingBackward(
            fromSegmentIndex: self.currentSegmentIndex, in: directory
        )
    }

    deinit {
        try? currentHandle.close()
    }

    private func rotateIfNeeded(adding bytes: UInt64) throws {
        guard currentSegmentSize + bytes > maxSegmentBytes else { return }
        try currentHandle.close()
        currentSegmentIndex += 1
        let next = directory.appendingPathComponent("\(currentSegmentIndex).seg")
        FileManager.default.createFile(atPath: next.path, contents: nil)
        currentHandle = try FileHandle(forUpdating: next)
        currentSegmentSize = 0
    }

    /// Append an event; returns the written entry.
    @discardableResult
    public func append(
        eventType: AuditEventType, fieldPath: String? = nil, ticketID: String? = nil, metadata: [String: String]? = nil
    ) throws -> AuditEntry {
        let entry = try AuditEntry(
            eventType: eventType, fieldPath: fieldPath, ticketID: ticketID, metadata: metadata, prevHashHex: cachedLastHash
        )
        let data = try encoder.encode(entry)
        let bytesToAdd = UInt64(data.count + 1) // newline

        try currentHandle.seekToEnd()
        try currentHandle.write(contentsOf: data)
        try currentHandle.write(contentsOf: Data([0x0A]))
        currentSegmentSize += bytesToAdd

        try rotateIfNeeded(adding: 0) // rotate for the *next* write, matching prior post-write behavior
        cachedLastHash = entry.hashHex
        return entry
    }

    // Read all segments in order
    public func allEntries() throws -> [AuditEntry] {
        try Self.allEntries(in: directory)
    }

    private static func allEntries(in directory: URL) throws -> [AuditEntry] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "seg" }
        let sorted = urls.sorted { segmentIndex($0) < segmentIndex($1) }
        var out: [AuditEntry] = []
        let decoder = Self.makeDecoder()
        for url in sorted {
            let data = try Data(contentsOf: url)
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                out.append(try decoder.decode(AuditEntry.self, from: Data(line)))
            }
        }
        return out
    }

    private static func segmentIndex(_ url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent) ?? 0
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Reads only the last line of `directory/<index>.seg`, walking
    /// backward through lower segment indices if the newest one is empty
    /// (immediately after a rotation) or missing — never decodes any entry
    /// but the one that matters.
    private static func lastHashHexSearchingBackward(fromSegmentIndex startIndex: Int, in directory: URL) throws -> String? {
        var index = startIndex
        while index >= 0 {
            let url = directory.appendingPathComponent("\(index).seg")
            if let hash = try lastHashHex(inSegmentAt: url) { return hash }
            index -= 1
        }
        return nil
    }

    private static func lastHashHex(inSegmentAt url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let lastLine = data.split(separator: 0x0A, omittingEmptySubsequences: true).last else { return nil }
        let entry = try makeDecoder().decode(AuditEntry.self, from: Data(lastLine))
        return entry.hashHex
    }

    // Return last hash if exists
    public func lastHash() -> String? {
        cachedLastHash
    }

    // Verify chain integrity across all segments
    public func verifyChain() -> Bool {
        let entries: [AuditEntry]
        do {
            entries = try allEntries()
        } catch {
            return false
        }
        var prev: String?
        for entry in entries {
            do {
                let payload = try AuditEntry.hashPayload(
                    id: entry.id, timestamp: entry.timestamp, eventType: entry.eventType, fieldPath: entry.fieldPath,
                    ticketID: entry.ticketID, metadata: entry.metadata, prevHashHex: entry.prevHashHex
                )
                let expected = AuditEntry.sha256Hex(payload)
                if expected != entry.hashHex { return false }
                if entry.prevHashHex != prev { return false }
                prev = entry.hashHex
            } catch {
                return false
            }
        }
        return true
    }

    // Tamper test helper: flip a byte in a segment file (tests only)
    #if DEBUG
    public func flipByteInSegment(index: Int, atOffset offset: UInt64) throws {
        let url = directory.appendingPathComponent("\(index).seg")
        var data = try Data(contentsOf: url)
        guard offset < data.count else { return }
        data[Int(offset)] = ~data[Int(offset)]
        try data.write(to: url)
    }
    #endif
}
