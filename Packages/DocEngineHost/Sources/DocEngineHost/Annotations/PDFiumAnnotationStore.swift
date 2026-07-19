import CPDFium
import Foundation
import PDFEngineAPI

/// `PDFiumEngine: AnnotationStore` (P1-04) — real PDFium-backed CRUD for
/// text-markup (and other spec-subtype) annotations via `fpdf_annot.h`.
///
/// Identity: PDF has no first-class "our UUID" concept, so this uses the
/// spec's own `/NM` key (ISO 32000-1: "the annotation name, a text string
/// uniquely identifying it among all the annotations on its page") to store
/// `Annotation.id.uuidString` — a standard key, not a custom hack, and
/// stable across page-index shuffles from other annotations being
/// added/removed.
///
/// `update` is implemented as remove-then-recreate rather than in-place
/// field mutation: PDFium's attachment-point API has no "replace all quads"
/// call (`FPDFAnnot_SetAttachmentPoints` replaces one indexed quad, but a
/// quad-count change — e.g. a highlight now spanning one fewer line — has
/// no clean partial-update path), so recreating with the same `/NM` is the
/// simplest correct approach and matches this store's small-CRUD-surface
/// contract (callers always supply the full desired state, never a delta).
///
/// **Known interop gap (see `tasks/escalations/E-009-p1-04-engine-save-missing.md`):**
/// none of this can reach disk yet — `PDFiumEngine.save` is unimplemented
/// (P1-21). Everything here is verified via PDFium's own read-back of what
/// it just wrote (`annotations(of:page:)` after `add`/`update`), not a
/// real file round-trip against Acrobat/Preview.
extension PDFiumEngine: AnnotationStore {
    public func annotations(of document: DocumentHandle, page: PageIndex) async throws -> [Annotation] {
        let pageHandle = try loadedPage(document, index: page.value)
        let count = FPDFPage_GetAnnotCount(pageHandle)
        guard count > 0 else { return [] }

        var results: [Annotation] = []
        results.reserveCapacity(Int(count))
        for index in 0..<count {
            guard let annot = FPDFPage_GetAnnot(pageHandle, index) else { continue }
            defer { FPDFPage_CloseAnnot(annot) }
            if let parsed = readAnnotation(annot, page: page) {
                results.append(parsed)
            }
        }
        return results
    }

    public func add(_ annotation: Annotation, to document: DocumentHandle) async throws {
        let pageHandle = try loadedPage(document, index: annotation.page.value)
        guard let fpdfSubtype = Self.fpdfSubtype(for: annotation.subtype) else {
            throw PDFEngineError.unsupportedFeature("annotationSubtypeNotSupported(\(annotation.subtype.rawValue))")
        }
        guard FPDFAnnot_IsSupportedSubtype(fpdfSubtype) != 0 else {
            throw PDFEngineError.unsupportedFeature("annotationSubtypeNotSupportedByEngine(\(annotation.subtype.rawValue))")
        }
        guard let annot = FPDFPage_CreateAnnot(pageHandle, fpdfSubtype) else {
            throw PDFEngineError.ioFailure("PDFium: failed to create annotation")
        }
        defer { FPDFPage_CloseAnnot(annot) }
        try writeAnnotation(annotation, into: annot)
    }

    public func update(_ annotation: Annotation, in document: DocumentHandle) async throws {
        guard let location = try findAnnotation(annotation.id, in: document) else {
            throw PDFEngineError.fieldNotFound(annotation.id.uuidString)
        }
        let existingPage = try loadedPage(document, index: location.pageIndex)
        guard FPDFPage_RemoveAnnot(existingPage, location.annotIndex) != 0 else {
            throw PDFEngineError.ioFailure("PDFium: failed to remove prior annotation state for update")
        }
        try await add(annotation, to: document)
    }

    public func remove(_ id: Annotation.ID, from document: DocumentHandle) async throws {
        guard let location = try findAnnotation(id, in: document) else {
            throw PDFEngineError.fieldNotFound(id.uuidString)
        }
        let pageHandle = try loadedPage(document, index: location.pageIndex)
        guard FPDFPage_RemoveAnnot(pageHandle, location.annotIndex) != 0 else {
            throw PDFEngineError.ioFailure("PDFium: failed to remove annotation")
        }
    }

    // MARK: - Read/write a single annotation object

    private func writeAnnotation(_ annotation: Annotation, into annot: OpaquePointer) throws {
        Self.withWideString(annotation.id.uuidString) { _ = FPDFAnnot_SetStringValue(annot, "NM", $0) }

        var rect = FS_RECTF(
            left: Float(annotation.boundingBox.origin.x),
            top: Float(annotation.boundingBox.origin.y + annotation.boundingBox.height),
            right: Float(annotation.boundingBox.origin.x + annotation.boundingBox.width),
            bottom: Float(annotation.boundingBox.origin.y)
        )
        guard FPDFAnnot_SetRect(annot, &rect) != 0 else {
            throw PDFEngineError.ioFailure("PDFium: failed to set annotation rect")
        }

        if Self.hasQuadPoints(annotation.subtype) {
            for quad in annotation.quadPoints {
                var q = FS_QUADPOINTSF(
                    x1: Float(quad.topLeft.x), y1: Float(quad.topLeft.y),
                    x2: Float(quad.topRight.x), y2: Float(quad.topRight.y),
                    x3: Float(quad.bottomLeft.x), y3: Float(quad.bottomLeft.y),
                    x4: Float(quad.bottomRight.x), y4: Float(quad.bottomRight.y)
                )
                guard FPDFAnnot_AppendAttachmentPoints(annot, &q) != 0 else {
                    throw PDFEngineError.ioFailure("PDFium: failed to append annotation quad points")
                }
            }
        }

        if let color = annotation.color {
            let r = UInt32(clamping: Int((color.red * 255).rounded()))
            let g = UInt32(clamping: Int((color.green * 255).rounded()))
            let b = UInt32(clamping: Int((color.blue * 255).rounded()))
            let a = UInt32(clamping: Int((annotation.opacity * 255).rounded()))
            // PDFium bakes annotation opacity (/CA) into this same call — our
            // `AnnotationColor.alpha` has no distinct PDF field (see ADR-014)
            // and is intentionally not read here.
            _ = FPDFAnnot_SetColor(annot, FPDFANNOT_COLORTYPE_Color, r, g, b, a)
        }

        if let author = annotation.author {
            Self.withWideString(author) { _ = FPDFAnnot_SetStringValue(annot, "T", $0) }
        }
        if let contents = annotation.contents {
            Self.withWideString(contents) { _ = FPDFAnnot_SetStringValue(annot, "Contents", $0) }
        }
        if let createdAt = annotation.createdAt {
            Self.withWideString(Self.pdfDateString(createdAt)) { _ = FPDFAnnot_SetStringValue(annot, "CreationDate", $0) }
        }
        Self.withWideString(Self.pdfDateString(annotation.modifiedAt ?? Date())) { _ = FPDFAnnot_SetStringValue(annot, "M", $0) }
    }

    private func readAnnotation(_ annot: OpaquePointer, page: PageIndex) -> Annotation? {
        guard let subtype = Self.annotationSubtype(for: FPDFAnnot_GetSubtype(annot)) else { return nil }

        let idString = Self.getStringValue(annot, key: "NM")
        let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()

        var boundingBox = PDFRect(x: 0, y: 0, width: 0, height: 0)
        var rect = FS_RECTF(left: 0, top: 0, right: 0, bottom: 0)
        if FPDFAnnot_GetRect(annot, &rect) != 0 {
            boundingBox = PDFRect(
                x: Double(rect.left), y: Double(rect.bottom),
                width: Double(rect.right - rect.left), height: Double(rect.top - rect.bottom)
            )
        }

        var quads: [PDFQuad] = []
        if Self.hasQuadPoints(subtype) {
            let quadCount = Int(FPDFAnnot_CountAttachmentPoints(annot))
            for index in 0..<quadCount {
                var q = FS_QUADPOINTSF(x1: 0, y1: 0, x2: 0, y2: 0, x3: 0, y3: 0, x4: 0, y4: 0)
                guard FPDFAnnot_GetAttachmentPoints(annot, index, &q) != 0 else { continue }
                quads.append(PDFQuad(
                    topLeft: PDFPoint(x: Double(q.x1), y: Double(q.y1)),
                    topRight: PDFPoint(x: Double(q.x2), y: Double(q.y2)),
                    bottomLeft: PDFPoint(x: Double(q.x3), y: Double(q.y3)),
                    bottomRight: PDFPoint(x: Double(q.x4), y: Double(q.y4))
                ))
            }
        }

        var color: AnnotationColor?
        var opacity = 1.0
        var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, a: UInt32 = 0
        if FPDFAnnot_GetColor(annot, FPDFANNOT_COLORTYPE_Color, &r, &g, &b, &a) != 0 {
            color = AnnotationColor(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
            opacity = Double(a) / 255
        }

        return Annotation(
            id: id,
            page: page,
            subtype: subtype,
            boundingBox: boundingBox,
            color: color,
            contents: Self.getStringValue(annot, key: "Contents"),
            author: Self.getStringValue(annot, key: "T"),
            modifiedAt: Self.getStringValue(annot, key: "M").flatMap(Self.parsePDFDate),
            quadPoints: quads,
            opacity: opacity,
            createdAt: Self.getStringValue(annot, key: "CreationDate").flatMap(Self.parsePDFDate)
        )
    }

    /// Scans every page for an annotation whose `/NM` matches `id`, since
    /// `AnnotationStore.remove(_:from:)` doesn't carry a page hint.
    private func findAnnotation(_ id: Annotation.ID, in document: DocumentHandle) throws -> (pageIndex: Int, annotIndex: Int32)? {
        let entry = try requireDocument(document)
        let pageCount = Int(FPDF_GetPageCount(entry.doc))
        for pageIndex in 0..<pageCount {
            let pageHandle = try loadedPage(document, index: pageIndex)
            let count = FPDFPage_GetAnnotCount(pageHandle)
            for annotIndex in 0..<count {
                guard let annot = FPDFPage_GetAnnot(pageHandle, annotIndex) else { continue }
                defer { FPDFPage_CloseAnnot(annot) }
                if Self.getStringValue(annot, key: "NM") == id.uuidString {
                    return (pageIndex, annotIndex)
                }
            }
        }
        return nil
    }

    // MARK: - Subtype mapping

    private static let subtypeToFPDF: [AnnotationSubtype: Int32] = [
        .text: FPDF_ANNOT_TEXT,
        .highlight: FPDF_ANNOT_HIGHLIGHT,
        .underline: FPDF_ANNOT_UNDERLINE,
        .strikeOut: FPDF_ANNOT_STRIKEOUT,
        .squiggly: FPDF_ANNOT_SQUIGGLY,
        .ink: FPDF_ANNOT_INK,
        .square: FPDF_ANNOT_SQUARE,
        .circle: FPDF_ANNOT_CIRCLE,
        .line: FPDF_ANNOT_LINE,
        .freeText: FPDF_ANNOT_FREETEXT,
        .stamp: FPDF_ANNOT_STAMP,
        .popup: FPDF_ANNOT_POPUP
    ]

    private static let fpdfToSubtype: [Int32: AnnotationSubtype] =
        Dictionary(uniqueKeysWithValues: subtypeToFPDF.map { ($1, $0) })

    private static func fpdfSubtype(for subtype: AnnotationSubtype) -> Int32? { subtypeToFPDF[subtype] }
    private static func annotationSubtype(for raw: Int32) -> AnnotationSubtype? { fpdfToSubtype[raw] }

    /// Only text-markup subtypes (+ link, which this store doesn't create)
    /// have `/QuadPoints` semantics — `fpdf_annot.h`'s own doc comment on
    /// `FPDFAnnot_HasAttachmentPoints`.
    private static func hasQuadPoints(_ subtype: AnnotationSubtype) -> Bool {
        switch subtype {
        case .highlight, .underline, .strikeOut, .squiggly: true
        default: false
        }
    }

    // MARK: - Wide-string bridging

    private static func withWideString<T>(_ string: String, _ body: (FPDF_WIDESTRING?) -> T) -> T {
        var units = Array(string.utf16)
        units.append(0)
        return units.withUnsafeBufferPointer { body($0.baseAddress) }
    }

    private static func getStringValue(_ annot: OpaquePointer, key: String) -> String? {
        let byteLength = FPDFAnnot_GetStringValue(annot, key, nil, 0)
        guard byteLength > 2 else { return nil }
        var units = [UInt16](repeating: 0, count: Int(byteLength) / 2)
        _ = units.withUnsafeMutableBufferPointer { buffer in
            FPDFAnnot_GetStringValue(annot, key, buffer.baseAddress, byteLength)
        }
        if let nul = units.firstIndex(of: 0) { units.removeSubrange(nul...) }
        let result = String(decoding: units, as: UTF16.self)
        return result.isEmpty ? nil : result
    }

    // MARK: - PDF date strings (ISO 32000-1 §7.9.4: "D:YYYYMMDDHHmmSS")

    private static func pdfDateString(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "D:%04d%02d%02d%02d%02d%02dZ",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
    }

    private static func parsePDFDate(_ string: String) -> Date? {
        guard string.hasPrefix("D:") else { return nil }
        let digits = Array(string.dropFirst(2).prefix(14))
        guard digits.count == 14, digits.allSatisfy(\.isNumber) else { return nil }

        var components = DateComponents()
        components.year = Int(String(digits[0..<4]))
        components.month = Int(String(digits[4..<6]))
        components.day = Int(String(digits[6..<8]))
        components.hour = Int(String(digits[8..<10]))
        components.minute = Int(String(digits[10..<12]))
        components.second = Int(String(digits[12..<14]))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: components)
    }
}
