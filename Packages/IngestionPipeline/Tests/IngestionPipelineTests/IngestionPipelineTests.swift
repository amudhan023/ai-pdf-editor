import XCTest
@testable import IngestionPipeline

final class IngestionPipelineTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(IngestionPipelineModule.name, "IngestionPipeline")
    }
}
