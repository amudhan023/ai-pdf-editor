import Foundation
import PDFEngineAPI

/// PDF/image/TXT -> `NormalizedDocument`. `DOCX`/`RTF` are detected but not
/// yet normalizable — a real import-allowlist gap, not an oversight:
/// `NSAttributedString`'s document-reading initializers for those types
/// (`.officeOpenXML`/`.rtf`) live in AppKit, and AppKit is not in this
/// package's allowlist (`IngestionSession`'s is, `IngestionPipeline`'s
/// isn't — see `Scripts/import-allowlist.txt`). Escalated rather than
/// silently importing AppKit or hand-rolling a DOCX-zip/XML or RTF-token
/// parser as a unilateral boundary call (CLAUDE.md §3.7). See this task's
/// `## Handoff` in `tasks/in-progress/P2-08-ingestion-stage-graph.md`.
public struct Normalizer: Sendable {
    /// Rejects input above this size before reading it, rather than after —
    /// bounded-memory handling for the "50MB photo" acceptance criterion:
    /// a single 50MB read is fine on a modern Mac, but the cap exists so a
    /// malicious/corrupt multi-GB file fails fast with a typed error
    /// instead of attempting an unbounded `Data(contentsOf:)`.
    public static let maxInputBytes = 200 * 1024 * 1024

    /// Scale used when rasterizing a PDF page for classification/OCR — high
    /// enough for Vision's text recognition to work well on typical body
    /// text, without ballooning the PNG transport size.
    private static let rasterScale = 1.5

    private let pageRenderer: PageRenderer
    private let textEditor: TextEditor?

    public init(pageRenderer: PageRenderer, textEditor: TextEditor? = nil) {
        self.pageRenderer = pageRenderer
        self.textEditor = textEditor
    }

    /// `document` is only consulted for `.pdf` input (an already-open
    /// `DocumentHandle` from the engine); other formats normalize straight
    /// from `fileURL`'s bytes.
    public func normalize(fileURL: URL, document: DocumentHandle? = nil) async throws -> NormalizedDocument {
        try Task.checkCancellation()

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = (attributes?[.size] as? Int) ?? 0
        guard size <= Self.maxInputBytes else {
            throw IngestionError.sizeLimitExceeded(bytes: size, limit: Self.maxInputBytes)
        }

        guard let handle = FileHandle(forReadingAtPath: fileURL.path) else {
            throw IngestionError.engine("could not open file for reading")
        }
        defer { try? handle.close() }
        let prefix = (try? handle.read(upToCount: 4096)) ?? Data()
        let format = DocumentFormat.detect(fileURL: fileURL, prefix: prefix)

        switch format {
        case .pdf:
            guard let document else {
                throw IngestionError.engine("PDF normalization requires an open DocumentHandle")
            }
            return try await normalizePDF(document: document, format: format)
        case .txt:
            return try normalizeText(fileURL: fileURL, format: format)
        case .jpeg, .png, .heic, .tiff:
            return try normalizeImage(fileURL: fileURL, format: format)
        case .docx, .rtf:
            throw IngestionError.unsupportedFormat(format)
        case .unknown:
            throw IngestionError.unsupportedFormat(format)
        }
    }

    private func normalizePDF(document: DocumentHandle, format: DocumentFormat) async throws -> NormalizedDocument {
        let count: Int
        do {
            count = try await pageRenderer.pageCount(of: document)
        } catch let error as PDFEngineError {
            throw IngestionError.corruptInput(format, reason: error.debugDescription)
        }

        var pages: [NormalizedPage] = []
        pages.reserveCapacity(count)
        for index in 0..<count {
            try Task.checkCancellation()
            let page = PageIndex(index)
            let text = try await textForPage(document: document, page: page)
            let imageData = try await rasterizedPNG(document: document, page: page)
            pages.append(NormalizedPage(index: page, text: text, imageData: imageData))
        }
        return NormalizedDocument(sourceFormat: format, pages: pages)
    }

    /// `nil` (not an error) when no `TextEditor` is wired or the page has no
    /// real text layer — both are legitimate "this page needs OCR" signals,
    /// not failures.
    private func textForPage(document: DocumentHandle, page: PageIndex) async throws -> String? {
        guard let textEditor else { return nil }
        let runs = try await textEditor.textRuns(of: document, page: page)
        guard !runs.isEmpty else { return nil }
        return runs.map(\.text).joined(separator: " ")
    }

    private func rasterizedPNG(document: DocumentHandle, page: PageIndex) async throws -> Data {
        let metadata: PageMetadata
        do {
            metadata = try await pageRenderer.metadata(of: document, page: page)
        } catch let error as PDFEngineError {
            throw IngestionError.engine(error.debugDescription)
        }
        let fullPageRect = PDFRect(x: 0, y: 0, width: metadata.size.width, height: metadata.size.height)
        let request = TileRenderRequest(page: page, tileRect: fullPageRect, scale: Self.rasterScale)
        let tile: RenderedTile
        do {
            tile = try await pageRenderer.renderTile(of: document, request: request)
        } catch let error as PDFEngineError {
            throw IngestionError.engine(error.debugDescription)
        }
        return PNGEncoder.encode(rgba: tile.pixelData, width: tile.pixelWidth, height: tile.pixelHeight)
    }

    private func normalizeText(fileURL: URL, format: DocumentFormat) throws -> NormalizedDocument {
        let text: String
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw IngestionError.corruptInput(format, reason: "not valid UTF-8")
        }
        return NormalizedDocument(sourceFormat: format, pages: [NormalizedPage(index: PageIndex(0), text: text)])
    }

    /// Images pass through as-is: `ImageIO` (on the `InferenceHost` side of
    /// the `imageData: Data` contract) decodes JPEG/PNG/HEIC/TIFF natively,
    /// and deskew/contrast preprocessing already happens there
    /// (`VisionOCRProvider.normalizeContrast`, P1-13) — this stage's job is
    /// just format detection + the size/corruption guard, not re-encoding.
    private func normalizeImage(fileURL: URL, format: DocumentFormat) throws -> NormalizedDocument {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw IngestionError.corruptInput(format, reason: "could not read file")
        }
        guard !data.isEmpty else {
            throw IngestionError.corruptInput(format, reason: "empty file")
        }
        return NormalizedDocument(sourceFormat: format, pages: [NormalizedPage(index: PageIndex(0), imageData: data)])
    }
}
