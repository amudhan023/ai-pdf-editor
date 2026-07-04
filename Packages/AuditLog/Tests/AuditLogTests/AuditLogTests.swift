import XCTest
@testable import AuditLog

final class AuditLogTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(AuditLogModule.name, "AuditLog")
    }
}
