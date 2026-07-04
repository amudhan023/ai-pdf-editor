import XCTest
@testable import VaultAPI

final class VaultAPITests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(VaultAPIModule.name, "VaultAPI")
    }
}
