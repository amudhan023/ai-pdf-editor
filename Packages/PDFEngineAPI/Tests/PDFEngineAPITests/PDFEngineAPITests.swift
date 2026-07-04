import XCTest
@testable import PDFEngineAPI

final class PDFEngineAPITests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(PDFEngineAPIModule.name, "PDFEngineAPI")
    }
}
