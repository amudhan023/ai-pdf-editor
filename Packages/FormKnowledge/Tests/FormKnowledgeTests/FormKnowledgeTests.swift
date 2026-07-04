import XCTest
@testable import FormKnowledge

final class FormKnowledgeTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(FormKnowledgeModule.name, "FormKnowledge")
    }
}
