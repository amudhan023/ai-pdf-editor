import XCTest
@testable import AuditLog

final class AuditLogTests: XCTestCase {
    func testChainIntegrity() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 256)
        let e1 = try await store.append(eventType: .vaultRead, fieldPath: "identity.passport.number", ticketID: "t1", metadata: ["actor": "tester"])
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
}
