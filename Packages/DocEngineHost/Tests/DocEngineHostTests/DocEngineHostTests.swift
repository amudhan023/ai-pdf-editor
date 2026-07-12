import XCTest
@testable import DocEngineHost

final class DocEngineHostTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(DocEngineHostModule.name, "DocEngineHost")
    }

    /// P0-03 acceptance criterion: DocEngineHost links the xcframework and
    /// calls FPDF_InitLibrary/FPDF_GetLastError successfully.
    func testPDFiumLibraryLinksAndInitializes() {
        let lastError = DocEngineHostModule.pdfiumLinkageCheck()
        XCTAssertEqual(lastError, 0, "FPDF_GetLastError should report FPDF_ERR_SUCCESS (0) after a clean init/destroy")
    }
}
