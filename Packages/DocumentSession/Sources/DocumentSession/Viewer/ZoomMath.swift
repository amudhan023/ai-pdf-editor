import Foundation
import PDFEngineAPI

/// How the viewer picks a page's display scale. `.custom` is the pinch/menu/
/// keyboard end state; `.fitPage`/`.fitWidth` recompute their scale whenever
/// the viewport or rotation changes rather than freezing a snapshot value.
public enum ZoomMode: Sendable, Equatable {
    case fitPage
    case fitWidth
    case custom(Double)
}

/// Pure zoom arithmetic — no view/state dependencies, so it's exhaustively
/// unit-testable (P1-01 Testing Requirements: "snapshot tests for zoom
/// modes" cover the rendered result; this covers the scale math itself).
public enum ZoomMath {
    public static let minScale = 0.25
    public static let maxScale = 8.0

    /// The scale (points-to-pixels/points) that satisfies `mode` for a page
    /// of `pageSize` (already rotation-adjusted by the caller) inside a
    /// viewport of `viewportSize`. Degenerate inputs (zero-size page or
    /// viewport) fall back to 1.0 rather than dividing by zero.
    public static func scale(for mode: ZoomMode, pageSize: PageSize, viewportSize: (width: Double, height: Double)) -> Double {
        switch mode {
        case .custom(let value):
            return clamp(value)
        case .fitWidth:
            guard pageSize.width > 0, viewportSize.width > 0 else { return 1.0 }
            return clamp(viewportSize.width / pageSize.width)
        case .fitPage:
            guard pageSize.width > 0, pageSize.height > 0, viewportSize.width > 0, viewportSize.height > 0 else { return 1.0 }
            return clamp(min(viewportSize.width / pageSize.width, viewportSize.height / pageSize.height))
        }
    }

    public static func clamp(_ scale: Double) -> Double {
        min(maxScale, max(minScale, scale))
    }

    /// Anchor-preserving zoom along one axis: given the current scroll
    /// offset (content coordinates at `oldScale`) and the anchor's position
    /// within the viewport (e.g. cursor location or pinch center, viewport
    /// coordinates — scale-independent), returns the new scroll offset at
    /// `newScale` so the same content point stays under the same
    /// viewport-relative position. Used for both pinch and keyboard/menu
    /// zoom so neither jumps the reader's place.
    public static func anchorPreservingOffset(
        oldOffset: Double,
        anchorViewportOffset: Double,
        oldScale: Double,
        newScale: Double
    ) -> Double {
        guard oldScale > 0 else { return oldOffset }
        let contentPoint = (oldOffset + anchorViewportOffset) / oldScale
        return contentPoint * newScale - anchorViewportOffset
    }
}
