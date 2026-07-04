import XCTest
@testable import InferenceAPI

final class InferenceAPITests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(InferenceAPIModule.name, "InferenceAPI")
    }
}
