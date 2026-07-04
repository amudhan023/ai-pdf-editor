import XCTest
@testable import VaultStore

final class VaultStoreTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(VaultStoreModule.name, "VaultStore")
    }
}
