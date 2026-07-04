import Foundation

/// A request to rasterize one tile of a page at a given scale. `tileRect` is
/// in page points (pre-scale); `scale` maps points to output pixels.
public struct TileRenderRequest: Sendable, Codable, Equatable {
    public let page: PageIndex
    public let tileRect: PDFRect
    public let scale: Double

    public init(page: PageIndex, tileRect: PDFRect, scale: Double) {
        self.page = page
        self.tileRect = tileRect
        self.scale = scale
    }
}

/// Rasterized pixel data for a `TileRenderRequest`. `pixelData` is raw RGBA8
/// bytes, row-major, `pixelWidth * pixelHeight * 4` bytes — the real
/// PDFium-backed implementation is expected to transport this via `IOSurface`
/// across XPC (ARCHITECTURE.md §3.3); this `Data`-based shape is what the
/// protocol and the in-process fake use.
public struct RenderedTile: Sendable, Equatable {
    public let request: TileRenderRequest
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let pixelData: Data

    public init(request: TileRenderRequest, pixelWidth: Int, pixelHeight: Int, pixelData: Data) {
        self.request = request
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.pixelData = pixelData
    }
}

/// Engine-neutral page rasterization. Implementations must never leak
/// engine-specific types (ARCHITECTURE.md §3.2's "must never" for this module).
public protocol PageRenderer: Sendable {
    func pageCount(of document: DocumentHandle) async throws -> Int
    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata
    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile
}
