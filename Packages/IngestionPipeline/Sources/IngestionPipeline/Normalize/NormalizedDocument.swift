import Foundation
import PDFEngineAPI

/// One page's worth of normalized content, ready for classification/OCR/
/// extraction. `text` is populated when the source has a real text layer
/// (born-digital PDF pages, TXT); `imageData` (PNG-encoded, see
/// `PNGEncoder`) is populated when a page needs to be treated visually —
/// classification always needs it, OCR needs it only when `text` is nil
/// (scanned/image-only page). Both may be present (a text-layer PDF page
/// still gets classified visually).
public struct NormalizedPage: Sendable, Equatable {
    public let index: PageIndex
    public let text: String?
    public let imageData: Data?

    public init(index: PageIndex, text: String? = nil, imageData: Data? = nil) {
        self.index = index
        self.text = text
        self.imageData = imageData
    }
}

/// The normalizer's output: source format + per-page content. A single-page
/// document (TXT, a standalone image) is modeled as one `NormalizedPage`
/// at index 0.
public struct NormalizedDocument: Sendable, Equatable {
    public let sourceFormat: DocumentFormat
    public let pages: [NormalizedPage]

    public init(sourceFormat: DocumentFormat, pages: [NormalizedPage]) {
        self.sourceFormat = sourceFormat
        self.pages = pages
    }
}
