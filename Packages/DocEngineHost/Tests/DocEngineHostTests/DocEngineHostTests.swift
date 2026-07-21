import XCTest
import PDFEngineAPI
@testable import DocEngineHost

final class DocEngineHostTests: XCTestCase {
    func testModuleAnchor() {
        XCTAssertEqual(DocEngineHostModule.name, "DocEngineHost")
    }

    /// P0-03 acceptance criterion: DocEngineHost links the xcframework and
    /// calls FPDF_InitLibrary/FPDF_GetLastError successfully.
    func testPDFiumLibraryLinksAndInitializes() {
        let lastError = DocEngineHostModule.pdfiumLinkageCheck()
        XCTAssertEqual(lastError, 0, "FPDF_GetLastError should report FPDF_ERR_SUCCESS (0) after a clean init/destroy")
    }
}

/// Real-PDFium-backed conformance and behavior tests (P0-06). Uses the
/// starter/malformed corpus from `Fixtures/pdf-corpus` (P0-08) — the same
/// fixtures `Scripts/bench.sh corpus-open` validates by hash.
final class PDFiumEngineTests: XCTestCase {
    private static var repoRoot: URL {
        // Tests/DocEngineHostTests/<this file>.swift -> repo root is 5
        // path components up (file, DocEngineHostTests/, Tests/,
        // DocEngineHost/, Packages/).
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func fixtureURL(_ relativePath: String) -> URL {
        Self.repoRoot.appendingPathComponent("Fixtures/pdf-corpus/\(relativePath)")
    }

    /// `PDFEngineConformanceSuite.verifyPageRenderer` requires `PageOrganizer`
    /// conformance too (page insert/delete/reorder/rotate — P1-06 scope, not
    /// implemented here), so this task exercises the same assertions the
    /// suite makes for `PageRenderer` directly, against a real PDFium-backed
    /// engine rather than `FakePDFEngine`.
    func testPageRendererConformanceAssertionsAgainstRealStarterFixture() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-f1040.pdf"))

        let count = try await engine.pageCount(of: document)
        XCTAssertGreaterThan(count, 0, "pageCount must be > 0 for a real document")

        let firstPage = PageIndex(0)
        let metadata = try await engine.metadata(of: document, page: firstPage)
        XCTAssertEqual(metadata.index, firstPage)
        XCTAssertGreaterThan(metadata.size.width, 0)
        XCTAssertGreaterThan(metadata.size.height, 0)

        let request = TileRenderRequest(page: firstPage, tileRect: PDFRect(x: 0, y: 0, width: 100, height: 100), scale: 2.0)
        let tile = try await engine.renderTile(of: document, request: request)
        XCTAssertEqual(tile.pixelWidth, 200)
        XCTAssertEqual(tile.pixelHeight, 200)
        XCTAssertEqual(tile.pixelData.count, tile.pixelWidth * tile.pixelHeight * 4)

        do {
            _ = try await engine.metadata(of: document, page: PageIndex(count + 1000))
            XCTFail("metadata(page:) must throw for an out-of-range page")
        } catch PDFEngineError.pageIndexOutOfRange {
            // expected
        }

        try await engine.close(document)
    }

    /// Data-driven from `Fixtures/pdf-corpus/manifest.json`'s `malformed_rows`
    /// (CLAUDE.md SS6: regression cases are fixture + manifest-row additions,
    /// not bespoke test scaffolding) — covers P0-08's original 5 plus this
    /// task's 2 fuzz-seed additions (`bit-flipped-body`/`bit-flipped-tail`)
    /// without needing a matching code change here.
    ///
    /// `bitFlippedBodyToleratedID` is the one row PDFium's xref-rebuild
    /// repair heuristic actually recovers (see its manifest row's
    /// `expected_behavior` for why) — the acceptance bar for all of them is
    /// "opens or fails gracefully, never crashes" (task's own Acceptance
    /// Criteria), not "every corrupted file must throw."
    func testOpenGracefullyRejectsEachMalformedFixture() async throws {
        let toleratedByPDFiumRepair: Set<String> = ["bit-flipped-body"]

        let data = try Data(contentsOf: fixtureURL("manifest.json"))
        let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let malformedRows = manifest?["malformed_rows"] as? [[String: Any]] ?? []
        XCTAssertFalse(malformedRows.isEmpty, "manifest.json should list at least one malformed fixture")

        let engine = PDFiumEngine()
        for row in malformedRows {
            let id = row["id"] as? String ?? "<unknown>"
            let file = row["file"] as? String ?? "<unknown>"
            do {
                let document = try await engine.open(url: fixtureURL(file))
                XCTAssertTrue(toleratedByPDFiumRepair.contains(id), "\(file) opened successfully but isn't in the known-tolerated allowlist")
                try await engine.close(document)
            } catch is PDFEngineError {
                // expected: a typed error, not a crash
            } catch {
                XCTFail("\(file) threw a non-PDFEngineError: \(error)")
            }
        }
    }

    func testOpenRejectsMissingFile() async {
        let engine = PDFiumEngine()
        do {
            _ = try await engine.open(url: fixtureURL("starter/does-not-exist.pdf"))
            XCTFail("should throw for a missing file")
        } catch PDFEngineError.ioFailure {
            // expected
        } catch {
            XCTFail("expected .ioFailure, got \(error)")
        }
    }

    func testMetadataThrowsForOutOfRangePage() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let count = try await engine.pageCount(of: document)
        XCTAssertGreaterThan(count, 0)

        do {
            _ = try await engine.metadata(of: document, page: PageIndex(count + 100))
            XCTFail("expected pageIndexOutOfRange")
        } catch PDFEngineError.pageIndexOutOfRange {
            // expected
        }
        try await engine.close(document)
    }

    func testCloseThenOperationsThrowDocumentNotFound() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw4.pdf"))
        try await engine.close(document)

        do {
            _ = try await engine.pageCount(of: document)
            XCTFail("expected documentNotFound after close")
        } catch PDFEngineError.documentNotFound {
            // expected
        }
    }

    /// P1-21 acceptance criterion: a real open -> mutate (add annotation) ->
    /// save -> reopen -> read-back cycle through the real engine, for both
    /// save modes. Writes to a scratch temp file, never back over the fixture.
    private func makeHighlightAnnotation() -> Annotation {
        Annotation(
            page: PageIndex(0), subtype: .highlight,
            boundingBox: PDFRect(x: 10, y: 10, width: 50, height: 20),
            quadPoints: [PDFQuad(
                topLeft: PDFPoint(x: 10, y: 30), topRight: PDFPoint(x: 60, y: 30),
                bottomLeft: PDFPoint(x: 10, y: 10), bottomRight: PDFPoint(x: 60, y: 10)
            )]
        )
    }

    private func withScratchOutputURL(_ body: (URL) async throws -> Void) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("P1-21-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try await body(url)
    }

    func testSaveFullRewriteRoundTripsMutatedAnnotationToDisk() async throws {
        try await withScratchOutputURL { outputURL in
            let engine = PDFiumEngine()
            let document = try await engine.open(url: fixtureURL("starter/uscis-i9.pdf"))
            let annotation = makeHighlightAnnotation()
            try await engine.add(annotation, to: document)

            try await engine.save(document, mode: .fullRewrite, to: outputURL)
            try await engine.close(document)

            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
            let reopened = try await engine.open(url: outputURL)
            let count = try await engine.pageCount(of: reopened)
            XCTAssertGreaterThan(count, 0)
            let annotations = try await engine.annotations(of: reopened, page: PageIndex(0))
            XCTAssertTrue(annotations.contains(where: { $0.id == annotation.id }), "the annotation added before save must survive a fullRewrite round-trip")
            try await engine.close(reopened)
        }
    }

    func testSaveIncrementalRoundTripsMutatedAnnotationToDisk() async throws {
        try await withScratchOutputURL { outputURL in
            let engine = PDFiumEngine()
            let document = try await engine.open(url: fixtureURL("starter/uscis-i9.pdf"))
            let annotation = makeHighlightAnnotation()
            try await engine.add(annotation, to: document)

            try await engine.save(document, mode: .incremental, to: outputURL)
            try await engine.close(document)

            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
            let reopened = try await engine.open(url: outputURL)
            let annotations = try await engine.annotations(of: reopened, page: PageIndex(0))
            XCTAssertTrue(annotations.contains(where: { $0.id == annotation.id }), "the annotation added before save must survive an incremental round-trip")
            try await engine.close(reopened)
        }
    }

    /// P1-05: the new geometry-drawn subtypes must survive the same
    /// file-persisted round-trip P1-21 unblocked for text markup — this is
    /// the "after repair" half of `E-009` for ink specifically (stamp's
    /// appended object and free text's `/DA` are exercised in-memory by
    /// `PDFiumAnnotationStoreTests`; picking one geometry-bearing subtype
    /// here is enough to prove `FPDF_SaveAsCopy` preserves `/InkList`, not
    /// just `/QuadPoints`).
    func testSaveRoundTripsInkAnnotationToDisk() async throws {
        try await withScratchOutputURL { outputURL in
            let engine = PDFiumEngine()
            let document = try await engine.open(url: fixtureURL("starter/uscis-i9.pdf"))
            let annotation = Annotation(
                page: PageIndex(0), subtype: .ink, boundingBox: PDFRect(x: 10, y: 10, width: 30, height: 30),
                inkPaths: [[PDFPoint(x: 10, y: 10), PDFPoint(x: 20, y: 40), PDFPoint(x: 30, y: 10)]]
            )
            try await engine.add(annotation, to: document)

            try await engine.save(document, mode: .fullRewrite, to: outputURL)
            try await engine.close(document)

            let reopened = try await engine.open(url: outputURL)
            let annotations = try await engine.annotations(of: reopened, page: PageIndex(0))
            let readBack = try XCTUnwrap(annotations.first(where: { $0.id == annotation.id }))
            XCTAssertEqual(readBack.inkPaths.count, 1)
            XCTAssertEqual(readBack.inkPaths.first?.count, 3)
            try await engine.close(reopened)
        }
    }

    /// Typed error surfacing (task requirement): a save whose destination
    /// can't be written (no such directory) must throw `.ioFailure`, never
    /// silently no-op or crash.
    func testSaveThrowsTypedIOFailureWhenDestinationIsUnwritable() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/uscis-i9.pdf"))
        let unwritableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("P1-21-no-such-dir-\(UUID().uuidString)")
            .appendingPathComponent("out.pdf")

        do {
            try await engine.save(document, mode: .fullRewrite, to: unwritableURL)
            XCTFail("save to a nonexistent directory should not silently succeed")
        } catch PDFEngineError.ioFailure {
            // expected
        }
        try await engine.close(document)
    }

    func testRenderTileOutputMatchesRequestedPixelSize() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-f4506t.pdf"))

        let request = TileRenderRequest(page: PageIndex(0), tileRect: PDFRect(x: 0, y: 0, width: 50, height: 80), scale: 1.5)
        let tile = try await engine.renderTile(of: document, request: request)

        XCTAssertEqual(tile.pixelWidth, 75)
        XCTAssertEqual(tile.pixelHeight, 120)
        XCTAssertEqual(tile.pixelData.count, tile.pixelWidth * tile.pixelHeight * 4)
        try await engine.close(document)
    }

    /// Pins the manifest row `synthetic-outlined-nested`'s `outline`
    /// expectations against real PDFium parsing (P1-02/ADR-013): nesting, an
    /// XYZ destination with an explicit zoom, and a structural heading with
    /// no `/Dest` surfacing as `destinationPage == nil`, not a fabricated
    /// page target.
    func testOutlineReaderParsesNestedBookmarksZoomAndUnlinkedHeading() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("synthetic/outlined-nested.pdf"))

        let roots = try await engine.outline(of: document)

        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots.first?.title, "Chapter 1")
        XCTAssertEqual(roots.first?.destinationPage, PageIndex(0))
        XCTAssertNil(roots.first?.zoom, "Chapter 1's XYZ dest has a null zoom slot")

        let child = roots.first?.children.first
        XCTAssertEqual(child?.title, "Section 1.1")
        XCTAssertEqual(child?.destinationPage, PageIndex(2))
        XCTAssertEqual(child?.zoom, 1.5)
        XCTAssertEqual(child?.children.isEmpty, true)

        XCTAssertEqual(roots.last?.title, "Unlinked Heading")
        XCTAssertNil(roots.last?.destinationPage)
        try await engine.close(document)
    }

    /// `PDFEngineConformanceSuite.verifyOutlineReaderEmpty` (P1-02/ADR-013)
    /// against a real PDFium-backed engine: the starter IRS fixtures have no
    /// `/Outlines` entry, so an empty result must not be an error or a
    /// fabricated entry.
    func testOutlineReaderConformanceAgainstRealFixtureWithNoOutline() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        try await PDFEngineConformanceSuite.verifyOutlineReaderEmpty(engine, document: document)
        try await engine.close(document)
    }

    /// P1-03: real extraction against the W-9 fixture. Pins content (the
    /// form's title must be present), geometry sanity (every run's box is
    /// non-degenerate, in page-point bounds, bottom-left origin), and
    /// per-run metadata (positive font size, correct page index). The
    /// manifest's `text_sha256` is a PDFKit-authored reference value —
    /// engine-for-engine byte equality of extracted text is not a realistic
    /// contract (segmentation/whitespace differ across extractors), so this
    /// asserts known-content containment instead; see the PR discussion.
    func testTextRunsExtractRealContentWithGeometry() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))

        let runs = try await engine.textRuns(of: document, page: PageIndex(0))

        XCTAssertGreaterThan(runs.count, 10, "the W-9 first page is text-dense")
        let joined = runs.map(\.text).joined(separator: " ")
        XCTAssertTrue(joined.contains("Request for Taxpayer"), "W-9 title must be extracted")

        let metadata = try await engine.metadata(of: document, page: PageIndex(0))
        for run in runs {
            XCTAssertEqual(run.page, PageIndex(0))
            XCTAssertGreaterThan(run.boundingBox.width, 0)
            XCTAssertGreaterThan(run.boundingBox.height, 0)
            XCTAssertGreaterThanOrEqual(run.boundingBox.origin.x, -1)
            XCTAssertGreaterThanOrEqual(run.boundingBox.origin.y, -1)
            XCTAssertLessThanOrEqual(run.boundingBox.origin.x + run.boundingBox.width, metadata.size.width + 1)
            XCTAssertLessThanOrEqual(run.boundingBox.origin.y + run.boundingBox.height, metadata.size.height + 1)
            XCTAssertGreaterThan(run.fontSize, 0)
        }
        try await engine.close(document)
    }

    func testReplaceTextFailsTypedNotSilently() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        do {
            try await engine.replaceText(of: document, run: UUID(), with: "x")
            XCTFail("replaceText must not silently succeed - editing is not P1-03 scope")
        } catch PDFEngineError.unsupportedFeature {
            // expected
        }
        try await engine.close(document)
    }

    func testMultipleDocumentsOpenIndependently() async throws {
        let engine = PDFiumEngine()
        let first = try await engine.open(url: fixtureURL("starter/irs-fw9.pdf"))
        let second = try await engine.open(url: fixtureURL("starter/irs-fw4.pdf"))

        let firstCount = try await engine.pageCount(of: first)
        let secondCount = try await engine.pageCount(of: second)
        XCTAssertEqual(firstCount, 6) // irs-fw9.pdf per Fixtures/pdf-corpus/manifest.json
        XCTAssertEqual(secondCount, 5) // irs-fw4.pdf per Fixtures/pdf-corpus/manifest.json

        try await engine.close(first)
        try await engine.close(second)
    }
}
