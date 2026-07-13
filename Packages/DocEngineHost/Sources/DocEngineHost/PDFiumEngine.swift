import CPDFium
import Foundation
import PDFEngineAPI

// FPDF_InitLibrary/FPDF_DestroyLibrary are process-wide and PDFium is not
// thread-safe (fpdfview.h's own header comment: "a single PDFium call can be
// made at a time"). A global `let` initializer runs exactly once and is
// thread-safe per the Swift runtime's guarantee for global/static storage,
// so this is the one safe place to do process-wide init without an actor.
private let pdfiumLibraryInitialized: Bool = {
    FPDF_InitLibrary()
    return true
}()

/// PDFium-backed implementation of `DocumentLifecycle` + `PageRenderer`
/// (P0-06). An `actor` because PDFium's C API is not thread-safe — actor
/// isolation gives us the "only one call at a time" serialization the
/// library requires for free, without a separate lock.
///
/// `save` conforms to `DocumentLifecycle` but is not implemented here: full
/// engine-side save modes (incremental/full-rewrite) are P1-16's remaining
/// scope, which was explicitly blocked on this task landing first. Calling
/// it throws a typed `.unsupportedFeature` error rather than silently
/// no-op'ing (CLAUDE.md SS15: never fake success).
public actor PDFiumEngine: DocumentLifecycle, PageRenderer {
    private struct OpenDocument {
        let doc: OpaquePointer
        var pages: [Int: OpaquePointer] = [:]
    }

    private var documents: [DocumentHandle: OpenDocument] = [:]

    public init() {
        _ = pdfiumLibraryInitialized
    }

    // MARK: - DocumentLifecycle

    public func open(url: URL) async throws -> DocumentHandle {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if accessedSecurityScope { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFEngineError.ioFailure("file not found")
        }

        guard let doc = FPDF_LoadDocument(url.path, nil) else {
            throw mapPDFiumError()
        }

        let handle = DocumentHandle()
        documents[handle] = OpenDocument(doc: doc)
        return handle
    }

    public func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {
        guard documents[document] != nil else { throw PDFEngineError.documentNotFound(document) }
        throw PDFEngineError.unsupportedFeature("engineSaveNotYetImplemented")
    }

    public func close(_ document: DocumentHandle) async throws {
        guard let entry = documents[document] else { throw PDFEngineError.documentNotFound(document) }
        for (_, page) in entry.pages { FPDF_ClosePage(page) }
        FPDF_CloseDocument(entry.doc)
        documents.removeValue(forKey: document)
    }

    // MARK: - PageRenderer

    public func pageCount(of document: DocumentHandle) async throws -> Int {
        let entry = try requireDocument(document)
        return Int(FPDF_GetPageCount(entry.doc))
    }

    public func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        let pageHandle = try loadedPage(document, index: page.value)
        let width = FPDF_GetPageWidth(pageHandle)
        let height = FPDF_GetPageHeight(pageHandle)
        let rotationSteps = ((Int(FPDFPage_GetRotation(pageHandle)) % 4) + 4) % 4
        let rotation = PageRotation(rawValue: rotationSteps * 90) ?? .none
        return PageMetadata(index: page, size: PageSize(width: width, height: height), rotation: rotation)
    }

    /// Renders exactly the requested tile at the requested scale — never the
    /// whole page — via `FPDF_RenderPageBitmapWithMatrix`'s arbitrary
    /// page-to-device transform (NFR-P5 groundwork: no full-document/full-page
    /// rasterization).
    public func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        let pageHandle = try loadedPage(document, index: request.page.value)

        let pixelWidth = max(1, Int((request.tileRect.width * request.scale).rounded()))
        let pixelHeight = max(1, Int((request.tileRect.height * request.scale).rounded()))

        guard let bitmap = FPDFBitmap_Create(Int32(pixelWidth), Int32(pixelHeight), 0) else {
            throw PDFEngineError.ioFailure("PDFium: failed to allocate render bitmap")
        }
        defer { FPDFBitmap_Destroy(bitmap) }

        // Opaque white background: PDF pages are opaque, and FPDFBitmap_Create
        // does not initialize the buffer.
        FPDFBitmap_FillRect(bitmap, 0, 0, Int32(pixelWidth), Int32(pixelHeight), 0xFFFFFFFF)

        let scale = Float(request.scale)
        // Page space (points, origin bottom-left, y-up) -> device space
        // (pixels, origin top-left of this tile, y-down): translate the
        // tile's top-left to the origin, then scale, flipping y.
        var matrix = FS_MATRIX(
            a: scale, b: 0, c: 0, d: -scale,
            e: Float(-request.tileRect.origin.x * request.scale),
            f: Float((request.tileRect.origin.y + request.tileRect.height) * request.scale)
        )
        var clip = FS_RECTF(left: 0, top: 0, right: Float(pixelWidth), bottom: Float(pixelHeight))
        FPDF_RenderPageBitmapWithMatrix(bitmap, pageHandle, &matrix, &clip, 0)

        let pixelData = try extractRGBA(from: bitmap, width: pixelWidth, height: pixelHeight)
        return RenderedTile(request: request, pixelWidth: pixelWidth, pixelHeight: pixelHeight, pixelData: pixelData)
    }

    // MARK: - Helpers

    private func requireDocument(_ handle: DocumentHandle) throws -> OpenDocument {
        guard let entry = documents[handle] else { throw PDFEngineError.documentNotFound(handle) }
        return entry
    }

    private func loadedPage(_ document: DocumentHandle, index: Int) throws -> OpaquePointer {
        var entry = try requireDocument(document)
        if let cached = entry.pages[index] { return cached }

        let count = Int(FPDF_GetPageCount(entry.doc))
        guard index >= 0, index < count else {
            throw PDFEngineError.pageIndexOutOfRange(index: index, pageCount: count)
        }
        guard let page = FPDF_LoadPage(entry.doc, Int32(index)) else {
            throw PDFEngineError.corruptDocument(reason: "PDFium: failed to load page (FPDF_LoadPage returned null)")
        }
        entry.pages[index] = page
        documents[document] = entry
        return page
    }

    /// PDFium's `FPDFBitmap_Create` output is BGRx (4 bytes/pixel, alpha byte
    /// unused since we created it with `alpha: 0`); `RenderedTile.pixelData`'s
    /// documented contract is RGBA8 — convert here rather than push the
    /// engine-specific byte order up through the protocol.
    private func extractRGBA(from bitmap: OpaquePointer, width: Int, height: Int) throws -> Data {
        let stride = Int(FPDFBitmap_GetStride(bitmap))
        guard let buffer = FPDFBitmap_GetBuffer(bitmap) else {
            throw PDFEngineError.ioFailure("PDFium: render produced no pixel buffer")
        }
        let source = buffer.assumingMemoryBound(to: UInt8.self)

        var rgba = Data(count: width * height * 4)
        rgba.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            let out = raw.bindMemory(to: UInt8.self)
            for row in 0..<height {
                let srcRowStart = row * stride
                let dstRowStart = row * width * 4
                for col in 0..<width {
                    let s = srcRowStart + col * 4
                    let d = dstRowStart + col * 4
                    out[d + 0] = source[s + 2] // R
                    out[d + 1] = source[s + 1] // G
                    out[d + 2] = source[s + 0] // B
                    out[d + 3] = 255 // opaque
                }
            }
        }
        return rgba
    }

    private func mapPDFiumError() -> PDFEngineError {
        let code = FPDF_GetLastError()
        switch code {
        case UInt(FPDF_ERR_FILE):
            return .ioFailure("PDFium: file could not be opened")
        case UInt(FPDF_ERR_FORMAT):
            return .corruptDocument(reason: "PDFium: not a valid PDF or corrupted (FPDF_ERR_FORMAT)")
        case UInt(FPDF_ERR_PASSWORD):
            // DocumentLifecycle.open(url:) has no password parameter (frozen
            // API, ADR-006) - a password-protected document fails open()
            // today with a typed, non-crashing error. Supplying a password
            // needs a protocol extension via a superseding ADR, not a
            // silent workaround here.
            return .unsupportedFeature("passwordProtectedDocument")
        case UInt(FPDF_ERR_SECURITY):
            return .unsupportedFeature("unsupportedSecurityScheme")
        case UInt(FPDF_ERR_PAGE):
            return .corruptDocument(reason: "PDFium: page not found or content error (FPDF_ERR_PAGE)")
        default:
            return .corruptDocument(reason: "PDFium: unknown error code \(code)")
        }
    }
}
