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
public actor PDFiumEngine: DocumentLifecycle, PageRenderer, OutlineReader, TextEditor {
    struct OpenDocument {
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

    // MARK: - OutlineReader

    /// Bounds recursion against malformed/cyclic bookmark trees (fpdf_doc.h's
    /// own doc comment: "the caller is responsible for handling circular
    /// bookmark references, as may arise from malformed documents") — a
    /// per-branch `visited` set also breaks any cycle immediately, this cap
    /// is a second, depth-based backstop.
    private static let maxOutlineDepth = 64

    public func outline(of document: DocumentHandle) async throws -> [OutlineNode] {
        let entry = try requireDocument(document)
        var visited = Set<OpaquePointer>()
        return outlineChildren(of: nil, in: entry.doc, depth: 0, visited: &visited)
    }

    private func outlineChildren(
        of parent: OpaquePointer?,
        in doc: OpaquePointer,
        depth: Int,
        visited: inout Set<OpaquePointer>
    ) -> [OutlineNode] {
        guard depth < Self.maxOutlineDepth else { return [] }

        var nodes: [OutlineNode] = []
        var current = FPDFBookmark_GetFirstChild(doc, parent)
        while let bookmark = current {
            guard visited.insert(bookmark).inserted else { break }

            var destinationPage: PageIndex?
            var zoom: Double?
            if let dest = FPDFBookmark_GetDest(doc, bookmark) {
                let pageIndex = FPDFDest_GetDestPageIndex(doc, dest)
                if pageIndex >= 0 { destinationPage = PageIndex(Int(pageIndex)) }

                var hasX: FPDF_BOOL = 0, hasY: FPDF_BOOL = 0, hasZoom: FPDF_BOOL = 0
                var x: FS_FLOAT = 0, y: FS_FLOAT = 0, z: FS_FLOAT = 0
                if FPDFDest_GetLocationInPage(dest, &hasX, &hasY, &hasZoom, &x, &y, &z) != 0, hasZoom != 0 {
                    zoom = Double(z)
                }
            }

            let children = outlineChildren(of: bookmark, in: doc, depth: depth + 1, visited: &visited)
            nodes.append(OutlineNode(
                title: bookmarkTitle(bookmark),
                destinationPage: destinationPage,
                zoom: zoom,
                children: children
            ))
            current = FPDFBookmark_GetNextSibling(doc, bookmark)
        }
        return nodes
    }

    /// PDFium returns bookmark titles as UTF-16LE, NUL-terminated
    /// (`fpdf_doc.h`'s `FPDFBookmark_GetTitle` doc comment) — decode here
    /// rather than push a wide-string type up through the protocol.
    private func bookmarkTitle(_ bookmark: OpaquePointer) -> String {
        let byteLength = FPDFBookmark_GetTitle(bookmark, nil, 0)
        guard byteLength > 0 else { return "" }

        var units = [UInt16](repeating: 0, count: Int(byteLength) / 2)
        _ = units.withUnsafeMutableBytes { raw in
            FPDFBookmark_GetTitle(bookmark, raw.baseAddress, byteLength)
        }
        if let nul = units.firstIndex(of: 0) {
            units.removeSubrange(nul...)
        }
        return String(decoding: units, as: UTF16.self)
    }

    // MARK: - TextEditor

    /// Extraction only (P1-03). Runs are PDFium's rect-based segmentation
    /// (`FPDFText_CountRects` over the whole page): one run per rectangle,
    /// in PDFium's text-object order — which is the PDF's reading order for
    /// well-formed documents. `TextRun.boundingBox` is the rect in page
    /// points (bottom-left origin, matching the tile-render coordinate
    /// contract). Per-glyph quads are deliberately not exposed: `TextRun`
    /// (frozen seam, ADR-006) carries one box per run; refining to quads is
    /// a superseding-ADR decision for whoever needs finer anchoring.
    public func textRuns(of document: DocumentHandle, page: PageIndex) async throws -> [TextRun] {
        let pagePointer = try loadedPage(document, index: page.value)
        guard let textPage = FPDFText_LoadPage(pagePointer) else {
            throw PDFEngineError.corruptDocument(reason: "PDFium: failed to load text page (FPDFText_LoadPage returned null)")
        }
        defer { FPDFText_ClosePage(textPage) }

        let rectCount = FPDFText_CountRects(textPage, 0, -1)
        guard rectCount > 0 else { return [] }

        var runs: [TextRun] = []
        runs.reserveCapacity(Int(rectCount))
        for rectIndex in 0..<rectCount {
            var left: Double = 0, top: Double = 0, right: Double = 0, bottom: Double = 0
            guard FPDFText_GetRect(textPage, rectIndex, &left, &top, &right, &bottom) != 0 else { continue }

            let text = boundedText(textPage, left: left, top: top, right: right, bottom: bottom)
            guard !text.isEmpty else { continue }

            // Font size via the character at the rect's center; 0/negative
            // (no char resolved, e.g. rotated text edge cases) degrades to
            // 12pt rather than failing the whole page (CLAUDE.md §15: total
            // on user-input-reachable paths).
            let charIndex = FPDFText_GetCharIndexAtPos(textPage, (left + right) / 2, (top + bottom) / 2, 2, 2)
            let fontSize = charIndex >= 0 ? FPDFText_GetFontSize(textPage, charIndex) : 0

            runs.append(TextRun(
                page: page,
                text: text,
                boundingBox: PDFRect(x: left, y: bottom, width: right - left, height: top - bottom),
                fontSize: fontSize > 0 ? fontSize : 12
            ))
        }
        return runs
    }

    /// In-place text replacement is the content-stream editing effort
    /// (`docs/ARCHITECTURE.md` §10.1, "the largest single build effort in
    /// the project") — its own task, not P1-03's extraction scope. Typed
    /// failure, never a silent no-op.
    public func replaceText(of document: DocumentHandle, run: TextRun.ID, with newText: String) async throws {
        _ = try requireDocument(document)
        throw PDFEngineError.unsupportedFeature("textReplacementNotYetImplemented")
    }

    /// `FPDFText_GetBoundedText` is UTF-16LE with the usual
    /// call-twice-for-length contract (same decode rationale as
    /// `bookmarkTitle`).
    private func boundedText(_ textPage: OpaquePointer, left: Double, top: Double, right: Double, bottom: Double) -> String {
        let length = FPDFText_GetBoundedText(textPage, left, top, right, bottom, nil, 0)
        guard length > 0 else { return "" }
        var units = [UInt16](repeating: 0, count: Int(length))
        _ = units.withUnsafeMutableBufferPointer { buffer in
            FPDFText_GetBoundedText(textPage, left, top, right, bottom, buffer.baseAddress, length)
        }
        if let nul = units.firstIndex(of: 0) {
            units.removeSubrange(nul...)
        }
        return String(decoding: units, as: UTF16.self)
    }

    // MARK: - Helpers

    func requireDocument(_ handle: DocumentHandle) throws -> OpenDocument {
        guard let entry = documents[handle] else { throw PDFEngineError.documentNotFound(handle) }
        return entry
    }

    func loadedPage(_ document: DocumentHandle, index: Int) throws -> OpaquePointer {
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

    func mapPDFiumError() -> PDFEngineError {
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
