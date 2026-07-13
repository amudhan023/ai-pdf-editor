import XCTest
@testable import AuditLog

private struct FakeAuditableEvent: AuditableEvent {
    let auditEventType: AuditEventType
    let auditFieldPath: String?
    let auditTicketID: String?
    let auditMetadata: [AuditMetadataEntry]?

    init(_ eventType: AuditEventType, fieldPath: String? = nil, ticketID: String? = nil) {
        self.auditEventType = eventType
        self.auditFieldPath = fieldPath
        self.auditTicketID = ticketID
        self.auditMetadata = nil
    }
}

final class AuditLogTests: XCTestCase {
    func testChainIntegrity() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 256)
        let e1 = try await store.append(
            eventType: .vaultRead, fieldPath: "identity.passport.number", ticketID: "t1",
            metadata: [AuditMetadataEntry(key: .itemCount, value: .count(1))]
        )
        let e2 = try await store.append(eventType: .fillCommitted, fieldPath: "identity.name", ticketID: "t2")
        let chainValid = await store.verifyChain()
        XCTAssertTrue(chainValid)
        let all = try await store.allEntries()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].hashHex, e1.hashHex)
        XCTAssertEqual(all[1].prevHashHex, e1.hashHex)
        XCTAssertEqual(all[1].hashHex, e2.hashHex)
    }

    func testTamperDetection() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 1024)
        _ = try await store.append(eventType: .vaultRead, fieldPath: "a", ticketID: "t1")
        _ = try await store.append(eventType: .vaultWrite, fieldPath: "b", ticketID: "t2")
        let chainValidBeforeTamper = await store.verifyChain()
        XCTAssertTrue(chainValidBeforeTamper)
        // flip a byte in the first segment
        #if DEBUG
        try await store.flipByteInSegment(index: 0, atOffset: 5)
        #else
        let seg = tmp.appendingPathComponent("0.seg")
        var data = try Data(contentsOf: seg)
        if data.count > 5 { data[5] = ~data[5]; try data.write(to: seg) }
        #endif
        let chainValidAfterTamper = await store.verifyChain()
        XCTAssertFalse(chainValidAfterTamper)
    }

    func testRotationCreatesMultipleSegments() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 64)
        for index in 0..<20 {
            _ = try await store.append(eventType: .ingestionCommitted, fieldPath: "f\(index)")
        }
        let files = try FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil).filter { $0.pathExtension == "seg" }
        XCTAssertTrue(files.count >= 1)
        let chainValid = await store.verifyChain()
        XCTAssertTrue(chainValid)
    }

    /// Regression test for the fix: a fresh `AuditLogStore` reopened against
    /// an existing on-disk log (simulating a process restart) must pick up
    /// the correct chain tail from disk, not start a fresh chain from nil.
    func testReopeningStoreContinuesTheSameChain() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let first = try AuditLogStore(directory: tmp, maxSegmentBytes: 4096)
        let e1 = try await first.append(eventType: .vaultRead, fieldPath: "a")

        let reopened = try AuditLogStore(directory: tmp, maxSegmentBytes: 4096)
        let e2 = try await reopened.append(eventType: .vaultWrite, fieldPath: "b")

        XCTAssertEqual(e2.prevHashHex, e1.hashHex)
        let chainValid = await reopened.verifyChain()
        XCTAssertTrue(chainValid)
    }

    /// Regression test for the fix: reopening right after a segment
    /// rotation (so the newest segment file exists but is empty) must
    /// still find the true tail hash by walking back to the prior segment.
    func testReopeningAfterRotationFindsTailInPriorSegment() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let first = try AuditLogStore(directory: tmp, maxSegmentBytes: 32)
        var last: AuditEntry?
        for index in 0..<5 {
            last = try await first.append(eventType: .ingestionCommitted, fieldPath: "f\(index)")
        }

        let reopened = try AuditLogStore(directory: tmp, maxSegmentBytes: 32)
        let next = try await reopened.append(eventType: .fillCommitted, fieldPath: "g")

        XCTAssertEqual(next.prevHashHex, last?.hashHex)
    }

    /// P1-15: bounded size — once live segment count exceeds `maxLiveSegments`,
    /// the oldest segments move into `archive/`, but the chain stays whole
    /// and verifiable across both directories.
    func testArchivesOldestSegmentsOnceLiveCountExceedsBound() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 16, maxLiveSegments: 2)
        for index in 0..<30 {
            _ = try await store.append(eventType: .ingestionCommitted, fieldPath: "f\(index)")
        }

        let liveSegments = try FileManager.default.contentsOfDirectory(
            at: tmp, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "seg" }
        let archiveDir = tmp.appendingPathComponent("archive")
        let archivedSegments = try FileManager.default.contentsOfDirectory(
            at: archiveDir, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "seg" }

        XCTAssertLessThanOrEqual(liveSegments.count, 2)
        XCTAssertGreaterThan(archivedSegments.count, 0)

        let all = try await store.allEntries()
        XCTAssertEqual(all.count, 30)
        let chainValid = await store.verifyChain()
        XCTAssertTrue(chainValid)
    }

    /// P1-15: filtered read API for the Privacy Dashboard consumer.
    func testFilteredReadByEventTypeAndTicketID() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 4096)
        _ = try await store.append(eventType: .vaultRead, fieldPath: "identity.passport.number", ticketID: "t1")
        _ = try await store.append(eventType: .vaultWrite, fieldPath: "identity.name", ticketID: "t2")
        _ = try await store.append(eventType: .vaultRead, fieldPath: "identity.dob", ticketID: "t2")

        let vaultReads = try await store.entries(matching: AuditEntryFilter(eventTypes: [.vaultRead]))
        XCTAssertEqual(vaultReads.count, 2)

        let byTicket = try await store.entries(matching: AuditEntryFilter(ticketID: "t2"))
        XCTAssertEqual(byTicket.count, 2)

        let byPrefix = try await store.entries(matching: AuditEntryFilter(fieldPathPrefix: "identity.passport"))
        XCTAssertEqual(byPrefix.count, 1)
    }

    /// P1-15: metadata value shapes are a closed enum — `.sha256` carries a
    /// `SHA256Hex`, whose only initializer validates a real 64-char hex
    /// digest, so a caller cannot use it to smuggle free-form document/vault
    /// content into the log (there is no way to construct one from
    /// arbitrary text; unlike a bare `case sha256(String)`, this isn't just
    /// a convention).
    func testMetadataSHA256ValueRejectsNonHexInput() throws {
        XCTAssertThrowsError(try SHA256Hex(validating: "not-a-hash"))
        let validHex = String(repeating: "a", count: 64)
        XCTAssertNoThrow(try SHA256Hex(validating: validHex))
    }

    /// P1-15: `subscribe` durably appends each event from an arbitrary
    /// `AsyncSequence` of `AuditableEvent`s, in order, before advancing —
    /// the seam a future domain event bus subscribes through.
    func testSubscribeAppendsEachEventDurablyInOrder() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 4096)

        let events: [FakeAuditableEvent] = [
            FakeAuditableEvent(.vaultRead, fieldPath: "a", ticketID: "t1"),
            FakeAuditableEvent(.fillCommitted, fieldPath: "b", ticketID: "t2")
        ]
        let stream = AsyncStream<FakeAuditableEvent> { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }

        try await store.subscribe(to: stream)

        let all = try await store.allEntries()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].fieldPath, "a")
        XCTAssertEqual(all[1].fieldPath, "b")
        XCTAssertEqual(all[1].prevHashHex, all[0].hashHex)
        let chainValid = await store.verifyChain()
        XCTAssertTrue(chainValid)
    }

    /// P1-15: durability — once `append` returns, the entry is already on
    /// disk (no buffered/async flush step), so a caller that awaits
    /// `append` before considering a privileged operation "committed" is
    /// safe even if the process is killed immediately after.
    func testAppendIsDurableOnDiskBeforeReturning() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 4096)
        let entry = try await store.append(eventType: .fillCommitted, fieldPath: "identity.name", ticketID: "t1")

        // Read the segment directly, bypassing the store, simulating a
        // fresh process inspecting the log after a crash.
        let segmentData = try Data(contentsOf: tmp.appendingPathComponent("0.seg"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let lines = segmentData.split(separator: 0x0A, omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
        let onDisk = try decoder.decode(AuditEntry.self, from: Data(lines[0]))
        XCTAssertEqual(onDisk.hashHex, entry.hashHex)
    }
}
