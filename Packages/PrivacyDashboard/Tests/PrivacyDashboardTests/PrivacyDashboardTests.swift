import XCTest
@testable import PrivacyDashboard

final class PrivacyDashboardTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(PrivacyDashboardModule.name, "PrivacyDashboard")
    }
}
