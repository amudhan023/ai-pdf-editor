import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class ZoomMathTests: XCTestCase {
    func testFitWidthScalesToViewportWidth() {
        let pageSize = PageSize(width: 600, height: 800)
        let scale = ZoomMath.scale(for: .fitWidth, pageSize: pageSize, viewportSize: (width: 300, height: 1000))
        XCTAssertEqual(scale, 0.5, accuracy: 0.0001)
    }

    func testFitPageScalesByTheTighterDimension() {
        let pageSize = PageSize(width: 600, height: 800)
        // Width would need 0.5, height would need 0.25 -> fitPage picks 0.25.
        let scale = ZoomMath.scale(for: .fitPage, pageSize: pageSize, viewportSize: (width: 300, height: 200))
        XCTAssertEqual(scale, 0.25, accuracy: 0.0001)
    }

    func testCustomScaleIsClampedToTheAllowedRange() {
        let pageSize = PageSize(width: 600, height: 800)
        let tooSmall = ZoomMath.scale(for: .custom(0.01), pageSize: pageSize, viewportSize: (width: 300, height: 200))
        let tooLarge = ZoomMath.scale(for: .custom(100), pageSize: pageSize, viewportSize: (width: 300, height: 200))
        XCTAssertEqual(tooSmall, ZoomMath.minScale)
        XCTAssertEqual(tooLarge, ZoomMath.maxScale)
    }

    func testDegenerateViewportFallsBackToOneWithoutDividingByZero() {
        let pageSize = PageSize(width: 600, height: 800)
        let scale = ZoomMath.scale(for: .fitWidth, pageSize: pageSize, viewportSize: (width: 0, height: 0))
        XCTAssertEqual(scale, 1.0)
    }

    func testAnchorPreservingOffsetKeepsTheSameContentPointUnderTheAnchor() {
        // Anchor sits 50pt into the viewport; content is scrolled 100pt down
        // at 1x. Doubling the scale should move the anchored content point
        // (150pt at 1x) to 300pt at 2x, so the new offset places it back at
        // the same 50pt viewport position: 300 - 50 = 250.
        let newOffset = ZoomMath.anchorPreservingOffset(
            oldOffset: 100,
            anchorViewportOffset: 50,
            oldScale: 1.0,
            newScale: 2.0
        )
        XCTAssertEqual(newOffset, 250, accuracy: 0.0001)
    }

    func testAnchorPreservingOffsetIsIdentityWhenScaleIsUnchanged() {
        let newOffset = ZoomMath.anchorPreservingOffset(
            oldOffset: 42,
            anchorViewportOffset: 10,
            oldScale: 1.5,
            newScale: 1.5
        )
        XCTAssertEqual(newOffset, 42, accuracy: 0.0001)
    }
}
