import Foundation

/// A page/image-relative bounding box, coordinates in `0...1` (origin
/// top-left). Deliberately not `PDFEngineAPI.Geometry`'s rect type — this
/// package is Foundation-only and imports nothing else (frozen seam, see
/// `Scripts/import-allowlist.txt`); OCR results are correlated back to page
/// geometry by the caller (`AutofillEngine`/`IngestionPipeline`), not here.
public struct NormalizedRect: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
