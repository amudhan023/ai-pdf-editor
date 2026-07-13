import Foundation

/// Append-only, hash-chained audit log (CLAUDE.md §7.9, §16 — audit entries
/// carry IDs/paths/hashes, never values). An `actor` so every append is
/// naturally serialized without a hand-rolled `DispatchQueue` (CLAUDE.md §4:
/// "no `DispatchQueue` in new code without justification").
///
/// `cachedLastHash` is the point of a prior rewrite: an earlier version
/// called `lastHash()` — which decodes every entry in every segment — on
/// every single `append`, making the log O(n^2) over its own lifetime. This
/// records the tail hash in memory at init (reading only the newest
/// non-empty segment's last line, not the whole log) and updates it after
/// each write, making `append` O(1) amortized in the common case.
public actor AuditLogStore {
    private let directory: URL
    private let archiveDirectory: URL
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
    /// Once the number of live (non-archived) segments exceeds this, the
    /// oldest ones are moved into `archiveDirectory` on the next rotation.
    /// Archived segments are still read by `allEntries`/`verifyChain` —
    /// "archival" bounds the hot working set, it doesn't destroy history.
    private let maxLiveSegments: Int
    private var cachedLastHash: String?

    public init(
        directory: URL,
        maxSegmentBytes: UInt64 = 64 * 1024,
        maxLiveSegments: Int = 64
    ) throws {
        self.directory = directory
        self.maxSegmentBytes = maxSegmentBytes
        self.maxLiveSegments = maxLiveSegments
        self.archiveDirectory = directory.appendingPathComponent("archive")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)

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
            fromSegmentIndex: self.currentSegmentIndex, liveDirectory: directory, archiveDirectory: archiveDirectory
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
        try archiveOldestSegmentsIfNeeded()
    }

    /// Moves the oldest live segments (everything but the current one) into
    /// `archiveDirectory` once the live count exceeds `maxLiveSegments`.
    /// Never touches the segment currently open for writing.
    private func archiveOldestSegmentsIfNeeded() throws {
        let live = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "seg" }
            .sorted { Self.segmentIndex($0) < Self.segmentIndex($1) }
        guard live.count > maxLiveSegments else { return }
        let overflow = live.count - maxLiveSegments
        for url in live.prefix(overflow) where Self.segmentIndex(url) != currentSegmentIndex {
            let destination = archiveDirectory.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: destination)
        }
    }

    /// Append an event; returns the written entry. Durable on return: the
    /// write is on disk (via `FileHandle.write`) before this actor call
    /// completes, so any caller that awaits `append` — including a future
    /// `subscribe` consumer — has the "audit entry is durable before the
    /// privileged operation is considered committed" guarantee this task
    /// requires, with no separate flush/ack step.
    @discardableResult
    public func append(
        eventType: AuditEventType,
        fieldPath: String? = nil,
        ticketID: String? = nil,
        metadata: [AuditMetadataEntry]? = nil
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

    /// Consumes any stream of `AuditableEvent`s (the seam a future domain
    /// event bus subscribes through), appending — and thus durably
    /// writing — each one before advancing to the next.
    public func subscribe<S: AsyncSequence>(to events: S) async throws where S.Element: AuditableEvent {
        for try await event in events {
            try append(
                eventType: event.auditEventType,
                fieldPath: event.auditFieldPath,
                ticketID: event.auditTicketID,
                metadata: event.auditMetadata
            )
        }
    }

    // Read all segments (archived + live) in order
    public func allEntries() throws -> [AuditEntry] {
        try Self.allEntries(liveDirectory: directory, archiveDirectory: archiveDirectory)
    }

    // Filtered read for dashboard/audit consumers.
    public func entries(matching filter: AuditEntryFilter) throws -> [AuditEntry] {
        try allEntries().filter(filter.matches)
    }

    private static func allEntries(liveDirectory: URL, archiveDirectory: URL) throws -> [AuditEntry] {
        let liveURLs = try FileManager.default.contentsOfDirectory(at: liveDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "seg" }
        let archivedURLs = try FileManager.default.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "seg" }
        let sorted = (liveURLs + archivedURLs).sorted { segmentIndex($0) < segmentIndex($1) }
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

    /// Reads only the last line of the newest segment (checking the live
    /// directory first, then the archive), walking backward through lower
    /// segment indices if the newest one is empty (immediately after a
    /// rotation) or missing — never decodes any entry but the one that matters.
    private static func lastHashHexSearchingBackward(
        fromSegmentIndex startIndex: Int, liveDirectory: URL, archiveDirectory: URL
    ) throws -> String? {
        var index = startIndex
        while index >= 0 {
            let liveURL = liveDirectory.appendingPathComponent("\(index).seg")
            if let hash = try lastHashHex(inSegmentAt: liveURL) { return hash }
            let archivedURL = archiveDirectory.appendingPathComponent("\(index).seg")
            if let hash = try lastHashHex(inSegmentAt: archivedURL) { return hash }
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

    // Verify chain integrity across all segments (archived + live)
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

    // Tamper test helper: flip a byte in a segment file, live or archived (tests only)
    #if DEBUG
    public func flipByteInSegment(index: Int, atOffset offset: UInt64) throws {
        let liveURL = directory.appendingPathComponent("\(index).seg")
        let url = FileManager.default.fileExists(atPath: liveURL.path)
            ? liveURL
            : archiveDirectory.appendingPathComponent("\(index).seg")
        var data = try Data(contentsOf: url)
        guard offset < data.count else { return }
        data[Int(offset)] = ~data[Int(offset)]
        try data.write(to: url)
    }
    #endif
}
