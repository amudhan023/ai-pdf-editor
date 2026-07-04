import XCTest
@testable import PDFEngineAPI

/// Every DTO that crosses XPC must round-trip through JSON losslessly
/// (root CLAUDE.md §4: "Sendable/Codable for anything crossing XPC").
final class CodableRoundTripTests: XCTestCase {
    private func assertRoundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testPageMetadataRoundTrip() throws {
        try assertRoundTrip(PageMetadata(index: PageIndex(3), size: PageSize(width: 612, height: 792), rotation: .clockwise180))
    }

    func testTileRenderRequestRoundTrip() throws {
        try assertRoundTrip(TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 1, y: 2, width: 3, height: 4), scale: 1.5))
    }

    func testTextRunRoundTrip() throws {
        try assertRoundTrip(TextRun(page: PageIndex(1), text: "hello", boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10), fontSize: 11))
    }

    func testPageOperationRoundTrip() throws {
        try assertRoundTrip(PageOperation.rotate(PageIndex(0), by: .clockwise90))
        try assertRoundTrip(PageOperation.insert(from: DocumentHandle(), sourcePage: PageIndex(0), at: PageIndex(1)))
    }

    func testAnnotationRoundTrip() throws {
        try assertRoundTrip(Annotation(
            page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 5, height: 5),
            color: AnnotationColor(red: 1, green: 0, blue: 0), contents: "note"
        ))
    }

    func testFormFieldRoundTrip() throws {
        try assertRoundTrip(FormField(
            name: "applicant.fullName", page: PageIndex(0), rect: PDFRect(x: 0, y: 0, width: 200, height: 20),
            kind: .text, formatHint: FormatHint(maxLength: 40), tooltip: "Full legal name", tabOrder: 0
        ))
    }

    func testPDFEngineErrorRoundTrip() throws {
        try assertRoundTrip(PDFEngineError.pageIndexOutOfRange(index: 5, pageCount: 3))
    }
}
