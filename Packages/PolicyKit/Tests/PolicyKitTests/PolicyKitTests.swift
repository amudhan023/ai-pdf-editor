import XCTest
@testable import PolicyKit

final class PolicyKitTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(PolicyKitModule.name, "PolicyKit")
    }
}
