import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class AnnotationUndoStackTests: XCTestCase {
    private func annotation(id: UUID = UUID()) -> Annotation {
        Annotation(id: id, page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testEmptyStackCannotUndoOrRedo() {
        var stack = AnnotationUndoStack()
        XCTAssertFalse(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
        XCTAssertNil(stack.undo())
        XCTAssertNil(stack.redo())
    }

    func testUndoOfAddReturnsRemoved() {
        var stack = AnnotationUndoStack()
        let annotation = annotation()
        stack.record(.added(annotation))

        XCTAssertTrue(stack.canUndo)
        XCTAssertEqual(stack.undo(), .removed(annotation))
        XCTAssertFalse(stack.canUndo)
        XCTAssertTrue(stack.canRedo)
    }

    func testRedoOfAddReplaysAdded() {
        var stack = AnnotationUndoStack()
        let annotation = annotation()
        stack.record(.added(annotation))
        _ = stack.undo()

        XCTAssertEqual(stack.redo(), .added(annotation))
        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
    }

    func testUndoOfRemoveReturnsAdded() {
        var stack = AnnotationUndoStack()
        let annotation = annotation()
        stack.record(.removed(annotation))

        XCTAssertEqual(stack.undo(), .added(annotation))
    }

    func testUndoOfUpdateSwapsBeforeAndAfter() {
        var stack = AnnotationUndoStack()
        let id = UUID()
        let before = annotation(id: id)
        let after = Annotation(
            id: id, page: before.page, subtype: before.subtype, boundingBox: before.boundingBox, contents: "changed"
        )
        stack.record(.updated(before: before, after: after))

        XCTAssertEqual(stack.undo(), .updated(before: after, after: before))
    }

    func testRecordingAfterUndoClearsRedoHistory() {
        var stack = AnnotationUndoStack()
        stack.record(.added(annotation()))
        _ = stack.undo()
        XCTAssertTrue(stack.canRedo)

        stack.record(.added(annotation()))
        XCTAssertFalse(stack.canRedo, "a fresh action after undo must discard redo history")
    }

    func testMultipleUndoRedoRoundTripsInOrder() {
        var stack = AnnotationUndoStack()
        let first = annotation()
        let second = annotation()
        stack.record(.added(first))
        stack.record(.added(second))

        XCTAssertEqual(stack.undo(), .removed(second))
        XCTAssertEqual(stack.undo(), .removed(first))
        XCTAssertNil(stack.undo())

        XCTAssertEqual(stack.redo(), .added(first))
        XCTAssertEqual(stack.redo(), .added(second))
        XCTAssertNil(stack.redo())
    }
}
