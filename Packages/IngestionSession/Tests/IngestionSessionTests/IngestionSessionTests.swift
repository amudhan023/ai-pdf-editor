import XCTest
@testable import IngestionSession

final class IngestionSessionTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(IngestionSessionModule.name, "IngestionSession")
    }
}
