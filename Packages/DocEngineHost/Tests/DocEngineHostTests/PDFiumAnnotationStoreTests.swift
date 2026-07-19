import XCTest
import PDFEngineAPI
@testable import DocEngineHost

/// P1-04: `PDFiumEngine: AnnotationStore` against a real PDFium-backed
/// document. These verify PDFium's own in-memory read-back of what it just
/// wrote; a real file-persisted save round-trip is covered separately by
/// `DocEngineHostTests`'s `testSave*RoundTripsMutatedAnnotationToDisk` tests
/// (P1-21).
final class PDFiumAnnotationStoreTests: XCTestCase {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func fixtureURL(_ relativePath: String) -> URL {
        Self.repoRoot.appendingPathComponent("Fixtures/pdf-corpus/\(relativePath)")
    }

    func testAnnotationStoreConformanceAgainstRealFixture() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        try await PDFEngineConformanceSuite.verifyAnnotationStore(engine, document: document, page: PageIndex(0))
        try await engine.close(document)
    }

    /// Multi-line highlight: two quads on different lines must round-trip
    /// in the same order with the same corner values (Z-order per ADR-014).
    func testMultiQuadHighlightRoundTripsInOrder() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let quads = [
            PDFQuad(
                topLeft: PDFPoint(x: 10, y: 100), topRight: PDFPoint(x: 80, y: 100),
                bottomLeft: PDFPoint(x: 10, y: 90), bottomRight: PDFPoint(x: 80, y: 90)
            ),
            PDFQuad(
                topLeft: PDFPoint(x: 10, y: 90), topRight: PDFPoint(x: 50, y: 90),
                bottomLeft: PDFPoint(x: 10, y: 80), bottomRight: PDFPoint(x: 50, y: 80)
            )
        ]
        let annotation = Annotation(
            page: PageIndex(0), subtype: .highlight,
            boundingBox: PDFRect(x: 10, y: 80, width: 70, height: 20), quadPoints: quads
        )
        try await engine.add(annotation, to: document)

        let annotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(annotations.first(where: { $0.id == annotation.id }))
        XCTAssertEqual(readBack.quadPoints.count, 2)
        for (expected, actual) in zip(quads, readBack.quadPoints) {
            XCTAssertEqual(actual.topLeft.x, expected.topLeft.x, accuracy: 0.01)
            XCTAssertEqual(actual.topLeft.y, expected.topLeft.y, accuracy: 0.01)
            XCTAssertEqual(actual.bottomRight.x, expected.bottomRight.x, accuracy: 0.01)
            XCTAssertEqual(actual.bottomRight.y, expected.bottomRight.y, accuracy: 0.01)
        }
        try await engine.close(document)
    }

    func testColorOpacityAuthorAndDatesRoundTrip() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let created = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(0) // whole-second boundary
        let created2 = Date(timeIntervalSinceReferenceDate: created.timeIntervalSinceReferenceDate.rounded())
        let annotation = Annotation(
            page: PageIndex(0), subtype: .underline,
            boundingBox: PDFRect(x: 5, y: 5, width: 30, height: 10),
            color: AnnotationColor(red: 0.2, green: 0.4, blue: 0.6),
            contents: "note text", author: "Ada Lovelace",
            quadPoints: [PDFQuad(
                topLeft: PDFPoint(x: 5, y: 15), topRight: PDFPoint(x: 35, y: 15),
                bottomLeft: PDFPoint(x: 5, y: 5), bottomRight: PDFPoint(x: 35, y: 5)
            )],
            opacity: 0.75, createdAt: created2
        )
        try await engine.add(annotation, to: document)

        let annotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(annotations.first(where: { $0.id == annotation.id }))

        let color = try XCTUnwrap(readBack.color)
        XCTAssertEqual(color.red, 0.2, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.4, accuracy: 0.01)
        XCTAssertEqual(color.blue, 0.6, accuracy: 0.01)
        XCTAssertEqual(readBack.opacity, 0.75, accuracy: 0.01)
        XCTAssertEqual(readBack.contents, "note text")
        XCTAssertEqual(readBack.author, "Ada Lovelace")
        let readCreatedAt = try XCTUnwrap(readBack.createdAt)
        XCTAssertEqual(readCreatedAt.timeIntervalSince1970, created2.timeIntervalSince1970, accuracy: 1)
        try await engine.close(document)
    }

    func testUpdatePreservesIdentityAcrossRewrite() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(
            page: PageIndex(0), subtype: .strikeOut, boundingBox: PDFRect(x: 1, y: 1, width: 10, height: 5),
            contents: "before"
        )
        try await engine.add(annotation, to: document)

        let updated = Annotation(
            id: annotation.id, page: annotation.page, subtype: annotation.subtype,
            boundingBox: annotation.boundingBox, contents: "after"
        )
        try await engine.update(updated, in: document)

        let annotations = try await engine.annotations(of: document, page: PageIndex(0))
        XCTAssertEqual(annotations.filter { $0.id == annotation.id }.count, 1, "update must not duplicate the annotation")
        XCTAssertEqual(annotations.first(where: { $0.id == annotation.id })?.contents, "after")
        try await engine.close(document)
    }

    func testRemoveFindsAnnotationWithoutPageHint() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(page: PageIndex(1), subtype: .squiggly, boundingBox: PDFRect(x: 1, y: 1, width: 10, height: 5))
        try await engine.add(annotation, to: document)
        try await engine.remove(annotation.id, from: document)

        let annotations = try await engine.annotations(of: document, page: PageIndex(1))
        XCTAssertFalse(annotations.contains(where: { $0.id == annotation.id }))
        try await engine.close(document)
    }

    func testUpdateOfUnknownIdThrowsFieldNotFound() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let ghost = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 1, height: 1))
        do {
            try await engine.update(ghost, in: document)
            XCTFail("update of an unknown id must throw")
        } catch PDFEngineError.fieldNotFound {
            // expected
        }
        try await engine.close(document)
    }

    /// `.line` is a valid `AnnotationSubtype` (mirrors the PDF spec) but not
    /// in PDFium's creatable-subtype list — must fail typed, not silently
    /// create a wrong-shaped annotation or crash.
    func testUnsupportedCreationSubtypeFailsTyped() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(page: PageIndex(0), subtype: .line, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        do {
            try await engine.add(annotation, to: document)
            XCTFail("PDFium does not support creating .line annotations via FPDFPage_CreateAnnot")
        } catch PDFEngineError.unsupportedFeature {
            // expected
        }
        try await engine.close(document)
    }
}
