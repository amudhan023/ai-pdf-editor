import XCTest
@testable import DocumentSession

final class DocumentSessionTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(DocumentSessionModule.name, "DocumentSession")
    }
}
