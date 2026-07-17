import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class ThumbnailSelectionModelTests: XCTestCase {
    func testPlainSelectReplacesAnyPriorSelection() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(1))
        model.select(PageIndex(4))
        XCTAssertEqual(model.selectedPages, [PageIndex(4)])
    }

    func testToggleAddsAndRemovesWithoutDisturbingOthers() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(1))
        model.toggle(PageIndex(3))
        XCTAssertEqual(model.selectedPages, [PageIndex(1), PageIndex(3)])
        model.toggle(PageIndex(1))
        XCTAssertEqual(model.selectedPages, [PageIndex(3)])
    }

    func testExtendSelectsContiguousRangeFromAnchor() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(2))
        model.extend(to: PageIndex(5))
        XCTAssertEqual(model.selectedPages, [PageIndex(2), PageIndex(3), PageIndex(4), PageIndex(5)])
    }

    func testExtendWorksBackwardFromAnchor() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(5))
        model.extend(to: PageIndex(3))
        XCTAssertEqual(model.selectedPages, [PageIndex(3), PageIndex(4), PageIndex(5)])
    }

    func testExtendReplacesRangeOnSecondShiftClickSameAnchor() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(2))
        model.extend(to: PageIndex(6))
        model.extend(to: PageIndex(3))
        XCTAssertEqual(model.selectedPages, [PageIndex(2), PageIndex(3)], "shift-click narrows back to the anchor's new range, macOS list semantics")
    }

    func testExtendWithNoAnchorBehavesAsPlainSelect() {
        var model = ThumbnailSelectionModel()
        model.extend(to: PageIndex(3))
        XCTAssertEqual(model.selectedPages, [PageIndex(3)])
    }

    func testToggleAfterExtendAnchorsRangeAtToggledPage() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(0))
        model.toggle(PageIndex(4))
        model.extend(to: PageIndex(6))
        XCTAssertEqual(model.selectedPages, [PageIndex(4), PageIndex(5), PageIndex(6)])
    }

    func testRemovingAnchorViaToggleFallsBackToLowestSelected() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(2))
        model.toggle(PageIndex(5))
        model.toggle(PageIndex(5))
        model.extend(to: PageIndex(4))
        XCTAssertEqual(model.selectedPages, [PageIndex(2), PageIndex(3), PageIndex(4)])
    }

    func testClearEmptiesSelectionAndAnchor() {
        var model = ThumbnailSelectionModel()
        model.select(PageIndex(1))
        model.clear()
        XCTAssertTrue(model.selectedPages.isEmpty)
        model.extend(to: PageIndex(2))
        XCTAssertEqual(model.selectedPages, [PageIndex(2)], "cleared anchor means extend degrades to plain select")
    }
}
