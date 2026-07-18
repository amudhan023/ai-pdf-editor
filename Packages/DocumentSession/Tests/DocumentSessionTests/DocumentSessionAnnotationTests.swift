import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class DocumentSessionAnnotationTests: XCTestCase {
    private func makeOpenSession(annotationStore: FakePDFEngine) async throws -> DocumentSession {
        let session = DocumentSession(lifecycle: annotationStore, renderer: annotationStore, annotationStore: annotationStore)
        try await session.open(url: URL(fileURLWithPath: "/tmp/doesnotneedtoexist.pdf"))
        return session
    }

    func testAnnotationsEmptyWhenStoreNotWired() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))

        let annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertEqual(annotations, [])
    }

    func testAddAnnotationPersistsAndIsUndoable() async throws {
        let engine = FakePDFEngine()
        let session = try await makeOpenSession(annotationStore: engine)

        let annotation = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        try await session.addAnnotation(annotation)

        var annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertEqual(annotations.map(\.id), [annotation.id])
        let canUndo = await session.canUndoAnnotation
        XCTAssertTrue(canUndo)

        let undone = try await session.undoAnnotation()
        XCTAssertTrue(undone)
        annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertTrue(annotations.isEmpty)
        let canRedo = await session.canRedoAnnotation
        XCTAssertTrue(canRedo)

        let redone = try await session.redoAnnotation()
        XCTAssertTrue(redone)
        annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertEqual(annotations.map(\.id), [annotation.id])
    }

    func testUpdateAnnotationIsUndoableBackToPriorState() async throws {
        let engine = FakePDFEngine()
        let session = try await makeOpenSession(annotationStore: engine)

        let annotation = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        try await session.addAnnotation(annotation)

        let changed = Annotation(
            id: annotation.id, page: annotation.page, subtype: annotation.subtype,
            boundingBox: annotation.boundingBox, contents: "note"
        )
        try await session.updateAnnotation(changed)
        var annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertEqual(annotations.first?.contents, "note")

        _ = try await session.undoAnnotation()
        annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertNil(annotations.first?.contents)
    }

    func testRemoveAnnotationIsUndoableBackToPresent() async throws {
        let engine = FakePDFEngine()
        let session = try await makeOpenSession(annotationStore: engine)

        let annotation = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        try await session.addAnnotation(annotation)

        try await session.removeAnnotation(annotation.id, page: PageIndex(0))
        var annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertTrue(annotations.isEmpty)

        _ = try await session.undoAnnotation()
        annotations = try await session.annotations(page: PageIndex(0))
        XCTAssertEqual(annotations.map(\.id), [annotation.id])
    }

    func testAddAnnotationThrowsWhenStoreNotWired() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))

        let annotation = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        do {
            try await session.addAnnotation(annotation)
            XCTFail("expected .unsupportedFeature when no annotationStore is wired")
        } catch DocumentSessionError.engine(.unsupportedFeature) {
            // expected
        }
    }

    func testUndoWithNoHistoryIsANoOp() async throws {
        let engine = FakePDFEngine()
        let session = try await makeOpenSession(annotationStore: engine)

        let undone = try await session.undoAnnotation()
        XCTAssertFalse(undone)
    }
}
