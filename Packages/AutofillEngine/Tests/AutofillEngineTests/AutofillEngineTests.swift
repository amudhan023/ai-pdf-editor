import XCTest
@testable import AutofillEngine

final class AutofillEngineTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(AutofillEngineModule.name, "AutofillEngine")
    }
}
