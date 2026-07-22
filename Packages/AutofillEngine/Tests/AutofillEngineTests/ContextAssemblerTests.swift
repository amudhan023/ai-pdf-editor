import XCTest
import PDFEngineAPI
@testable import AutofillEngine

final class ContextAssemblerTests: XCTestCase {
    private func field(rect: PDFRect, tooltip: String? = "First Name") -> FormField {
        FormField(name: "field1", page: 0, rect: rect, kind: .text, tooltip: tooltip, tabOrder: 0)
    }

    func test_runsWithinMaxDistance_areIncludedAsNearbyText() {
        let fieldRect = PDFRect(x: 100, y: 100, width: 50, height: 20)
        let closeRun = TextRun(page: 0, text: "Enter your legal name", boundingBox: PDFRect(x: 100, y: 130, width: 80, height: 12), fontSize: 10)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect), pageTextRuns: [closeRun], maxDistance: 150)
        XCTAssertTrue(context.nearbyText.contains("Enter your legal name") || context.sectionHeaders.contains("Enter your legal name"))
    }

    func test_runsBeyondMaxDistance_areExcluded() {
        let fieldRect = PDFRect(x: 0, y: 0, width: 50, height: 20)
        let farRun = TextRun(page: 0, text: "Unrelated footer text", boundingBox: PDFRect(x: 5000, y: 5000, width: 80, height: 12), fontSize: 10)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect), pageTextRuns: [farRun], maxDistance: 150)
        XCTAssertTrue(context.nearbyText.isEmpty)
        XCTAssertTrue(context.sectionHeaders.isEmpty)
    }

    func test_runsOnOtherPages_areExcluded() {
        let fieldRect = PDFRect(x: 0, y: 0, width: 50, height: 20)
        let otherPageRun = TextRun(page: 1, text: "Page 2 content", boundingBox: PDFRect(x: 5, y: 5, width: 80, height: 12), fontSize: 10)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect), pageTextRuns: [otherPageRun], maxDistance: 150)
        XCTAssertTrue(context.nearbyText.isEmpty)
    }

    func test_largeFontRunRelativeToNeighbors_isTreatedAsSectionHeader() {
        let fieldRect = PDFRect(x: 100, y: 100, width: 50, height: 20)
        let header = TextRun(page: 0, text: "Personal Information", boundingBox: PDFRect(x: 100, y: 140, width: 80, height: 12), fontSize: 24)
        let plain1 = TextRun(page: 0, text: "First", boundingBox: PDFRect(x: 100, y: 120, width: 40, height: 10), fontSize: 10)
        let plain2 = TextRun(page: 0, text: "Name", boundingBox: PDFRect(x: 145, y: 120, width: 40, height: 10), fontSize: 10)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect), pageTextRuns: [header, plain1, plain2], maxDistance: 150)
        XCTAssertEqual(context.sectionHeaders, ["Personal Information"])
        XCTAssertEqual(Set(context.nearbyText), Set(["First", "Name"]))
    }

    func test_assembledText_ordersLabelThenTooltipThenHeadersThenNearbyText() {
        let context = MatchContext(label: "First Name", tooltip: "Legal first name", nearbyText: ["nearby"], sectionHeaders: ["Section"])
        XCTAssertEqual(context.assembledText, "First Name Legal first name Section nearby")
    }

    func test_tooltipPreferredOverFieldNameForLabel() {
        let fieldRect = PDFRect(x: 0, y: 0, width: 50, height: 20)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect, tooltip: "Legal First Name"), pageTextRuns: [])
        XCTAssertEqual(context.label, "Legal First Name")
    }

    func test_missingTooltip_fallsBackToFieldName() {
        let fieldRect = PDFRect(x: 0, y: 0, width: 50, height: 20)
        let context = ContextAssembler.assemble(field: field(rect: fieldRect, tooltip: nil), pageTextRuns: [])
        XCTAssertEqual(context.label, "field1")
    }
}
