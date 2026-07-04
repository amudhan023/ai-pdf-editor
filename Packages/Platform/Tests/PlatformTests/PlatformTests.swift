import XCTest
@testable import Platform

final class PlatformTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(PlatformModule.name, "Platform")
    }
}
