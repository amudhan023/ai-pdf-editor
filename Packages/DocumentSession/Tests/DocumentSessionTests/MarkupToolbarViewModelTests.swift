import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class MarkupToolbarViewModelTests: XCTestCase {
    @MainActor
    private func makeOpenSession() async throws -> (DocumentSession, FakePDFEngine) {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine, annotationStore: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/doesnotneedtoexist.pdf"))
        return (session, engine)
    }

    private func run(page: PageIndex = PageIndex(0)) -> TextRun {
        TextRun(page: page, text: "hello", boundingBox: PDFRect(x: 0, y: 0, width: 20, height: 10), fontSize: 12)
    }

    @MainActor
    func testCreateMarkupUsesSelectedSubtypeAndColorAsSingleQuad() async throws {
        let (session, _) = try await makeOpenSession()
        let markup = MarkupToolbarViewModel(session: session)
        markup.selectedSubtype = .underline
        let color = AnnotationColor(red: 0.4, green: 0.7, blue: 1.0)
        markup.selectedColor = color

        await markup.createMarkup(on: run())

        let annotations = markup.annotationsByPage[PageIndex(0)] ?? []
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations.first?.subtype, .underline)
        XCTAssertEqual(annotations.first?.color, color)
        XCTAssertEqual(annotations.first?.quadPoints.count, 1)
    }

    @MainActor
    func testSelectAndDeleteRemovesAnnotationAndClearsSelection() async throws {
        let (session, _) = try await makeOpenSession()
        let markup = MarkupToolbarViewModel(session: session)
        await markup.createMarkup(on: run())
        let id = try XCTUnwrap(markup.annotationsByPage[PageIndex(0)]?.first?.id)

        markup.selectAnnotation(id)
        await markup.deleteSelected(page: PageIndex(0))

        XCTAssertNil(markup.selectedAnnotationID)
        XCTAssertEqual(markup.annotationsByPage[PageIndex(0)], [])
    }

    @MainActor
    func testDeleteSelectedWithNoSelectionIsANoOp() async throws {
        let (session, _) = try await makeOpenSession()
        let markup = MarkupToolbarViewModel(session: session)
        await markup.createMarkup(on: run())

        await markup.deleteSelected(page: PageIndex(0))

        XCTAssertEqual(markup.annotationsByPage[PageIndex(0)]?.count, 1)
    }

    @MainActor
    func testUndoRedoReflectedInPublishedState() async throws {
        let (session, _) = try await makeOpenSession()
        let markup = MarkupToolbarViewModel(session: session)
        await markup.loadAnnotations(page: PageIndex(0))
        XCTAssertFalse(markup.canUndo)

        await markup.createMarkup(on: run())
        XCTAssertTrue(markup.canUndo)
        XCTAssertFalse(markup.canRedo)

        await markup.undo(page: PageIndex(0))
        XCTAssertEqual(markup.annotationsByPage[PageIndex(0)], [])
        XCTAssertFalse(markup.canUndo)
        XCTAssertTrue(markup.canRedo)

        await markup.redo(page: PageIndex(0))
        XCTAssertEqual(markup.annotationsByPage[PageIndex(0)]?.count, 1)
    }

    @MainActor
    func testLoadAnnotationsSetsErrorWhenStoreNotWired() async throws {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/a.pdf"))
        let markup = MarkupToolbarViewModel(session: session)

        await markup.createMarkup(on: run())

        XCTAssertNotNil(markup.lastError)
        XCTAssertEqual(markup.annotationsByPage[PageIndex(0)], nil)
    }
}
