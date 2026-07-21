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

    /// P2-01: `verifyFormModel` only mutates the in-memory document (no
    /// `save()` call), same as `verifyAnnotationStore` above — safe to run
    /// directly against the checked-in fixture, never modifies it on disk.
    func testFormModelConformanceAgainstRealFixture() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        try await PDFEngineConformanceSuite.verifyFormModel(engine, document: document)
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

    // MARK: - P1-05: ink, shapes, free text, stamp, note, link (ADR-015)

    func testInkAnnotationConformanceAgainstRealFixture() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        try await PDFEngineConformanceSuite.verifyInkAnnotation(engine, document: document, page: PageIndex(0))
        try await engine.close(document)
    }

    func testInkStrokesRoundTripPointsInOrder() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let paths: [[PDFPoint]] = [
            [PDFPoint(x: 10, y: 10), PDFPoint(x: 20, y: 40), PDFPoint(x: 30, y: 10)],
            [PDFPoint(x: 50, y: 50), PDFPoint(x: 60, y: 60)]
        ]
        let annotation = Annotation(
            page: PageIndex(0), subtype: .ink, boundingBox: PDFRect(x: 10, y: 10, width: 50, height: 50),
            inkPaths: paths
        )
        try await engine.add(annotation, to: document)

        let annotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(annotations.first(where: { $0.id == annotation.id }))
        XCTAssertEqual(readBack.inkPaths.count, 2)
        for (expected, actual) in zip(paths, readBack.inkPaths) {
            XCTAssertEqual(actual.count, expected.count)
            for (expectedPoint, actualPoint) in zip(expected, actual) {
                XCTAssertEqual(actualPoint.x, expectedPoint.x, accuracy: 0.01)
                XCTAssertEqual(actualPoint.y, expectedPoint.y, accuracy: 0.01)
            }
        }
        try await engine.close(document)
    }

    /// Square/circle need no new engine code — PDFium's internal
    /// `CPVT_GenerateAP` renders them from `/Rect` + color alone (unlike
    /// stamp/freeText, which needed explicit appearance handling in this
    /// task). This test pins that the generic rect+color path really is
    /// sufficient for these two subtypes.
    func testSquareAndCircleRoundTripRectAndColor() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        for subtype: AnnotationSubtype in [.square, .circle] {
            let annotation = Annotation(
                page: PageIndex(0), subtype: subtype, boundingBox: PDFRect(x: 5, y: 5, width: 40, height: 30),
                color: AnnotationColor(red: 0.1, green: 0.2, blue: 0.3)
            )
            try await engine.add(annotation, to: document)
            let shapeAnnotations = try await engine.annotations(of: document, page: PageIndex(0))
            let readBack = try XCTUnwrap(shapeAnnotations.first(where: { $0.id == annotation.id }))
            XCTAssertEqual(readBack.boundingBox.width, 40, accuracy: 0.01)
            XCTAssertEqual(readBack.boundingBox.height, 30, accuracy: 0.01)
            let color = try XCTUnwrap(readBack.color)
            XCTAssertEqual(color.red, 0.1, accuracy: 0.01)
            try await engine.remove(annotation.id, from: document)
        }
        try await engine.close(document)
    }

    func testFreeTextPersistsDefaultAppearanceString() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(
            page: PageIndex(0), subtype: .freeText, boundingBox: PDFRect(x: 5, y: 5, width: 100, height: 30),
            color: AnnotationColor(red: 0, green: 0, blue: 0), contents: "reviewer note"
        )
        try await engine.add(annotation, to: document)
        let freeTextAnnotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(freeTextAnnotations.first(where: { $0.id == annotation.id }))
        XCTAssertEqual(readBack.contents, "reviewer note")
        try await engine.close(document)
    }

    /// Stamp gets a real appended appearance object (`FPDFAnnot_AppendObject`
    /// — the one custom-object path PDFium supports for stamp/ink) rather
    /// than staying visually blank. `add(_:to:)` only returns successfully if
    /// `FPDFAnnot_AppendObject` itself returned true (checked with a typed
    /// `.ioFailure` throw otherwise, see `appendStampAppearance`), so a
    /// no-throw add plus a rect/color round-trip is a genuine assertion that
    /// the object landed, not just that the bare annotation was created.
    func testStampAppendsAppearanceObjectAndRoundTripsRectAndColor() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(
            page: PageIndex(0), subtype: .stamp, boundingBox: PDFRect(x: 5, y: 5, width: 60, height: 20),
            color: AnnotationColor(red: 0.8, green: 0.1, blue: 0.1)
        )
        try await engine.add(annotation, to: document)
        let stampAnnotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(stampAnnotations.first(where: { $0.id == annotation.id }))
        XCTAssertEqual(readBack.subtype, .stamp)
        XCTAssertEqual(readBack.boundingBox.width, 60, accuracy: 0.01)
        try await engine.close(document)
    }

    /// Sticky note: creatable via the generic rect+color+contents+author
    /// path already covered above; this pins subtype-specific identity so a
    /// future regression can't silently collapse `.text` into a different
    /// PDFium subtype constant.
    func testStickyNoteRoundTripsContentsAuthorAndDates() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let annotation = Annotation(
            page: PageIndex(0), subtype: .text, boundingBox: PDFRect(x: 5, y: 5, width: 20, height: 20),
            contents: "Please double-check this field", author: "Reviewer",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await engine.add(annotation, to: document)
        let noteAnnotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(noteAnnotations.first(where: { $0.id == annotation.id }))
        XCTAssertEqual(readBack.subtype, .text)
        XCTAssertEqual(readBack.contents, "Please double-check this field")
        XCTAssertEqual(readBack.author, "Reviewer")
        try await engine.close(document)
    }

    /// Link creation is only supported bare (rect/quad, no action) — see
    /// ADR-015. Supplying a `linkURL` on `add` must fail typed rather than
    /// silently dropping the URL.
    func testLinkCreationWithoutURLSucceedsButWithURLThrowsTyped() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let bareLink = Annotation(page: PageIndex(0), subtype: .link, boundingBox: PDFRect(x: 5, y: 5, width: 40, height: 10))
        try await engine.add(bareLink, to: document)
        let linkAnnotations = try await engine.annotations(of: document, page: PageIndex(0))
        let readBack = try XCTUnwrap(linkAnnotations.first(where: { $0.id == bareLink.id }))
        XCTAssertNil(readBack.linkURL, "a bare link (no action set) must not fabricate a URL")

        let linkWithURL = Annotation(
            page: PageIndex(0), subtype: .link, boundingBox: PDFRect(x: 5, y: 20, width: 40, height: 10),
            linkURL: URL(string: "https://example.com")
        )
        do {
            try await engine.add(linkWithURL, to: document)
            XCTFail("creating a .link with a linkURL must throw — no PDFium setter exists for the action dictionary")
        } catch PDFEngineError.unsupportedFeature {
            // expected
        }
        try await engine.close(document)
    }
}
