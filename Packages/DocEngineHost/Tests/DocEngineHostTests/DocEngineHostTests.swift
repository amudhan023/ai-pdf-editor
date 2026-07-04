import XCTest
@testable import DocEngineHost

final class DocEngineHostTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(DocEngineHostModule.name, "DocEngineHost")
    }
}
