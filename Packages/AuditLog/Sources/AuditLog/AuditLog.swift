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

    // Construct and compute hash using canonical JSON (sorted keys)
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

        // compute hash
        let payload = try AuditEntry.hashPayload(id: id,
                                                 timestamp: timestamp,
                                                 eventType: eventType,
                                                 fieldPath: fieldPath,
                                                 ticketID: ticketID,
                                                 metadata: metadata,
                                                 prevHashHex: prevHashHex)
        self.hashHex = AuditEntry.sha256Hex(payload)
    }

    // Produce the canonical payload JSON used for hashing (exclude hashHex itself)
    static func hashPayload(id: UUID, timestamp: Date, eventType: AuditEventType, fieldPath: String?, ticketID: String?, metadata: [String: String]?, prevHashHex: String?) throws -> Data {
        // Deterministic encoding: dictionary with sorted keys
        var dict = [String: Any]()
        dict["id"] = id.uuidString
        dict["timestamp"] = ISO8601DateFormatter().string(from: timestamp)
        dict["eventType"] = eventType.rawValue
        if let fieldPath = fieldPath { dict["fieldPath"] = fieldPath }
        if let ticketID = ticketID { dict["ticketID"] = ticketID }
        if let metadata = metadata { dict["metadata"] = metadata }
        if let prev = prevHashHex { dict["prevHashHex"] = prev }

        // JSONEncoder with sorted keys
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return jsonData
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

public final class AuditLogStore {
    private let directory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let fileHandleQueue = DispatchQueue(label: "AuditLogStore.fileHandle")
    private var currentHandle: FileHandle
    private var currentSegmentIndex: Int
    private var currentSegmentSize: UInt64 = 0
    private let maxSegmentBytes: UInt64

    public init(directory: URL, maxSegmentBytes: UInt64 = 64 * 1024) throws {
        self.directory = directory
        self.maxSegmentBytes = maxSegmentBytes
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // discover highest segment
        let existing = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "seg" }
        let indices = existing.compactMap { Int($0.deletingPathExtension().lastPathComponent) }
        self.currentSegmentIndex = indices.max() ?? 0
        let segmentURL = directory.appendingPathComponent("\(self.currentSegmentIndex).seg")
        if FileManager.default.fileExists(atPath: segmentURL.path) {
            self.currentHandle = try FileHandle(forUpdating: segmentURL)
            self.currentSegmentSize = try self.currentHandle.seekToEnd() as UInt64
        } else {
            FileManager.default.createFile(atPath: segmentURL.path, contents: nil)
            self.currentHandle = try FileHandle(forUpdating: segmentURL)
            self.currentSegmentSize = 0
        }
    }

    deinit {
        try? currentHandle.close()
    }

    private func rotateIfNeeded(adding bytes: UInt64) throws {
        if currentSegmentSize + bytes > maxSegmentBytes {
            try currentHandle.close()
            currentSegmentIndex += 1
            let next = directory.appendingPathComponent("\(currentSegmentIndex).seg")
            FileManager.default.createFile(atPath: next.path, contents: nil)
            currentHandle = try FileHandle(forUpdating: next)
            currentSegmentSize = 0
        }
    }

    // Append an event; returns the written entry
    public func append(eventType: AuditEventType, fieldPath: String? = nil, ticketID: String? = nil, metadata: [String: String]? = nil) throws -> AuditEntry {
        return try fileHandleQueue.sync {
            // get prev hash from last entry if any
            let prev = try lastHash()
            let entry = try AuditEntry(eventType: eventType, fieldPath: fieldPath, ticketID: ticketID, metadata: metadata, prevHashHex: prev)
            let data = try encoder.encode(entry)
            let bytesToAdd = UInt64(data.count + 1) // newline
            try currentHandle.seekToEnd()
            try currentHandle.write(contentsOf: data)
            try currentHandle.write(contentsOf: Data([0x0A]))
            currentSegmentSize += bytesToAdd
            // rotate after write if we've exceeded the limit, preparing for next append
            if currentSegmentSize > maxSegmentBytes {
                try currentHandle.close()
                currentSegmentIndex += 1
                let next = directory.appendingPathComponent("\(currentSegmentIndex).seg")
                FileManager.default.createFile(atPath: next.path, contents: nil)
                currentHandle = try FileHandle(forUpdating: next)
                currentSegmentSize = 0
            }
            return entry
        }
    }

    // Read all segments in order
    public func allEntries() throws -> [AuditEntry] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "seg" }
        let sorted = urls.sorted { (a, b) -> Bool in
            let aIndex = Int(a.deletingPathExtension().lastPathComponent) ?? 0
            let bIndex = Int(b.deletingPathExtension().lastPathComponent) ?? 0
            return aIndex < bIndex
        }
        var out: [AuditEntry] = []
        for url in sorted {
            let data = try Data(contentsOf: url)
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            for line in lines {
                let entry = try decoder.decode(AuditEntry.self, from: Data(line))
                out.append(entry)
            }
        }
        return out
    }

    // Return last hash if exists
    public func lastHash() throws -> String? {
        let entries = try allEntries()
        return entries.last?.hashHex
    }

    // Verify chain integrity across all segments
    public func verifyChain() -> Bool {
        let entries: [AuditEntry]
        do {
            entries = try allEntries()
        } catch {
            return false
        }
        var prev: String? = nil
        for e in entries {
            do {
                let payload = try AuditEntry.hashPayload(id: e.id,
                                                        timestamp: e.timestamp,
                                                        eventType: e.eventType,
                                                        fieldPath: e.fieldPath,
                                                        ticketID: e.ticketID,
                                                        metadata: e.metadata,
                                                        prevHashHex: e.prevHashHex)
                let expected = AuditEntry.sha256Hex(payload)
                if expected != e.hashHex { return false }
                if e.prevHashHex != prev { return false }
                prev = e.hashHex
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
