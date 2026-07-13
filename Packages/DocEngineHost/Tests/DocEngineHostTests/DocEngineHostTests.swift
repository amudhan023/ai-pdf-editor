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

    func testSaveIsNotYetImplementedButFailsTyped() async throws {
        let engine = PDFiumEngine()
        let document = try await engine.open(url: fixtureURL("starter/uscis-i9.pdf"))

        do {
            try await engine.save(document, mode: .fullRewrite, to: fixtureURL("starter/uscis-i9.pdf"))
            XCTFail("save should not silently succeed - engine-side save modes are P1-16 scope")
        } catch PDFEngineError.unsupportedFeature {
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
