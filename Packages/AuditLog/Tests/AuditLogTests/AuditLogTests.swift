import XCTest
@testable import AuditLog

final class AuditLogTests: XCTestCase {
    func testChainIntegrity() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 256)
        let e1 = try store.append(eventType: .vaultRead, fieldPath: "identity.passport.number", ticketID: "t1", metadata: ["actor":"tester"]) 
        let e2 = try store.append(eventType: .fillCommitted, fieldPath: "identity.name", ticketID: "t2")
        XCTAssertTrue(try store.verifyChain())
        let all = try store.allEntries()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].hashHex, e1.hashHex)
        XCTAssertEqual(all[1].prevHashHex, e1.hashHex)
    }

    func testTamperDetection() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 1024)
        _ = try store.append(eventType: .vaultRead, fieldPath: "a", ticketID: "t1")
        _ = try store.append(eventType: .vaultWrite, fieldPath: "b", ticketID: "t2")
        XCTAssertTrue(try store.verifyChain())
        // flip a byte in the first segment
        #if DEBUG
        try store.flipByteInSegment(index: 0, atOffset: 5)
        #else
        let seg = tmp.appendingPathComponent("0.seg")
        var data = try Data(contentsOf: seg)
        if data.count > 5 { data[5] = ~data[5]; try data.write(to: seg) }
        #endif
        XCTAssertFalse(try store.verifyChain())
    }

    func testRotationCreatesMultipleSegments() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = try AuditLogStore(directory: tmp, maxSegmentBytes: 64)
        for i in 0..<20 {
            _ = try store.append(eventType: .ingestionCommitted, fieldPath: "f\(i)")
        }
        let files = try FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil).filter { $0.pathExtension == "seg" }
        XCTAssertTrue(files.count >= 1)
        XCTAssertTrue(store.verifyChain())
    }
}
