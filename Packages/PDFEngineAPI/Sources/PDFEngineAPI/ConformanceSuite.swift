import Foundation

/// A conformance check failed. Carries a human-readable reason; test targets
/// (`XCTAssertNoThrow`/`catch`) turn these into failures with useful output.
public struct ConformanceFailure: Error, CustomStringConvertible {
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
    public var description: String { reason }
}

/// Protocol-conformance checks any real engine implementation must also pass —
/// shipped here (not in `Tests/`) so `DocEngineHost`'s test target can import
/// `PDFEngineAPI` and run the same suite against the PDFium-backed engine
/// once it exists, per this task's Testing Requirements.
public enum PDFEngineConformanceSuite {
    /// Exercises `PageRenderer` + `PageOrganizer` against a document that
    /// already has at least one page.
    public static func verifyPageRenderer<E: PageRenderer & PageOrganizer>(
        _ engine: E,
        document: DocumentHandle
    ) async throws {
        let count = try await engine.pageCount(of: document)
        guard count > 0 else { throw ConformanceFailure("pageCount must be > 0 for a seeded document") }

        let firstPage = PageIndex(0)
        let metadata = try await engine.metadata(of: document, page: firstPage)
        guard metadata.index == firstPage else {
            throw ConformanceFailure("metadata(page:).index must equal the requested page")
        }
        guard metadata.size.width > 0, metadata.size.height > 0 else {
            throw ConformanceFailure("page size must be positive")
        }

        let request = TileRenderRequest(page: firstPage, tileRect: PDFRect(x: 0, y: 0, width: 100, height: 100), scale: 2.0)
        let tile = try await engine.renderTile(of: document, request: request)
        guard tile.pixelWidth == 200, tile.pixelHeight == 200 else {
            throw ConformanceFailure("renderTile output pixel size must equal tileRect size * scale")
        }
        guard tile.pixelData.count == tile.pixelWidth * tile.pixelHeight * 4 else {
            throw ConformanceFailure("renderTile pixelData must be RGBA8: width*height*4 bytes")
        }

        var threwForOutOfRange = false
        do {
            _ = try await engine.metadata(of: document, page: PageIndex(count + 1000))
        } catch {
            threwForOutOfRange = true
        }
        guard threwForOutOfRange else {
            throw ConformanceFailure("metadata(page:) must throw for an out-of-range page")
        }
    }

    /// Exercises `AnnotationStore` add/update/remove round-trip.
    public static func verifyAnnotationStore<E: AnnotationStore>(_ engine: E, document: DocumentHandle, page: PageIndex) async throws {
        let annotation = Annotation(page: page, subtype: .highlight, boundingBox: PDFRect(x: 10, y: 10, width: 50, height: 20))
        try await engine.add(annotation, to: document)

        let afterAdd = try await engine.annotations(of: document, page: page)
        guard afterAdd.contains(where: { $0.id == annotation.id }) else {
            throw ConformanceFailure("annotations(page:) must include a just-added annotation")
        }

        var updated = annotation
        updated = Annotation(
            id: annotation.id, page: annotation.page, subtype: annotation.subtype,
            boundingBox: annotation.boundingBox, contents: "updated"
        )
        try await engine.update(updated, in: document)
        let afterUpdate = try await engine.annotations(of: document, page: page)
        guard afterUpdate.first(where: { $0.id == annotation.id })?.contents == "updated" else {
            throw ConformanceFailure("update(_:) must persist the change")
        }

        try await engine.remove(annotation.id, from: document)
        let afterRemove = try await engine.annotations(of: document, page: page)
        guard !afterRemove.contains(where: { $0.id == annotation.id }) else {
            throw ConformanceFailure("remove(_:) must delete the annotation")
        }
    }

    /// Exercises `FormModel` read + `setValue` round-trip. Caller must have
    /// already seeded at least one field (this protocol has no "create
    /// field" operation — AcroForm fields come from the document itself).
    public static func verifyFormModel<E: FormModel>(_ engine: E, document: DocumentHandle) async throws {
        let fields = try await engine.fields(of: document)
        guard let field = fields.first else {
            throw ConformanceFailure("verifyFormModel requires at least one pre-seeded field")
        }

        try await engine.setValue("conformance-test-value", for: field.id, in: document)
        let updated = try await engine.fields(of: document)
        guard updated.first(where: { $0.id == field.id })?.currentValue == "conformance-test-value" else {
            throw ConformanceFailure("setValue(_:for:) must persist and be visible via fields(of:)")
        }

        var threwForUnknownField = false
        do {
            try await engine.setValue("x", for: "definitely-not-a-real-field-id", in: document)
        } catch {
            threwForUnknownField = true
        }
        guard threwForUnknownField else {
            throw ConformanceFailure("setValue(_:for:) must throw for an unknown field id")
        }
    }
}
