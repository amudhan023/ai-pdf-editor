import XCTest
@testable import InferenceHost

final class InferenceHostTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(InferenceHostModule.name, "InferenceHost")
    }
}
