import XCTest
@testable import AutofillSession

final class AutofillSessionTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(AutofillSessionModule.name, "AutofillSession")
    }
}
