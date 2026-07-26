import CPDFium
import XCTest
import PDFEngineAPI
@testable import DocEngineHost

/// P1-06: `PDFiumEngine: PageOrganizer` — example-case coverage per
/// operation, plus a property-based random-op-sequence round trip (the
/// task's "any sequence of 50 random page ops -> save -> reopen -> structure
/// matches expectation, zero corruption" acceptance criterion). Uses
/// synthetic documents (built directly via `CPDFium`, allowed in this
/// package's test allowlist) rather than the real-form corpus, since the
/// property test needs each page to carry a cheap, stable identity
/// (distinct page *width*, in points) to verify against after arbitrary
/// reordering/duplication — real fixture forms are uniform US-Letter
/// throughout and can't provide that on their own.
final class PDFiumPageOrganizerTests: XCTestCase {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func scratchDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Builds a document with one page per entry in `pageWidths` (each
    /// `FPDFPage_New`'d at that width, 792pt height — the width is this
    /// test's per-page identity tag) and writes it to a scratch file.
    private func makeSyntheticDocument(pageWidths: [Double], in dir: URL, name: String) throws -> URL {
        // FPDF_CreateNewDocument needs FPDF_InitLibrary already called —
        // normally a side effect of constructing a PDFiumEngine, but this
        // helper builds a document *before* any engine exists in some
        // tests, so force it explicitly rather than depend on call order.
        _ = PDFiumEngine()
        guard let doc = FPDF_CreateNewDocument() else {
            throw XCTSkip("PDFium: FPDF_CreateNewDocument returned null")
        }
        defer { FPDF_CloseDocument(doc) }
        for (index, width) in pageWidths.enumerated() {
            guard let page = FPDFPage_New(doc, Int32(index), width, 792) else {
                XCTFail("FPDFPage_New failed for index \(index)")
                continue
            }
            FPDF_ClosePage(page)
        }
        let url = dir.appendingPathComponent(name)
        let data = try pdfiumSaveAsCopy(doc, flags: FPDF_DWORD(FPDF_NO_INCREMENTAL))
        try data.write(to: url)
        return url
    }

    // MARK: - Example-case coverage

    func testDeleteRemovesPageAndShiftsIndices() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeSyntheticDocument(pageWidths: [100, 200, 300], in: dir, name: "a.pdf")

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)
        try await engine.apply(.delete(PageIndex(1)), to: document)

        let count = try await engine.pageCount(of: document)
        XCTAssertEqual(count, 2)
        let remaining = try await [
            engine.metadata(of: document, page: PageIndex(0)).size.width,
            engine.metadata(of: document, page: PageIndex(1)).size.width,
        ]
        XCTAssertEqual(remaining, [100, 300])
    }

    func testDeletingTheOnlyRemainingPageThrowsTyped() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeSyntheticDocument(pageWidths: [100], in: dir, name: "a.pdf")

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)
        do {
            try await engine.apply(.delete(PageIndex(0)), to: document)
            XCTFail("expected .unsupportedFeature when deleting the only remaining page")
        } catch PDFEngineError.unsupportedFeature {
            // expected
        }
    }

    func testReorderMovesPageToTargetIndex() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeSyntheticDocument(pageWidths: [100, 200, 300, 400], in: dir, name: "a.pdf")

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)
        // [100,200,300,400] -> move index 3 (400) to index 1 -> [100,400,200,300]
        try await engine.apply(.reorder(from: PageIndex(3), to: PageIndex(1)), to: document)

        var widths: [Double] = []
        for i in 0..<4 {
            widths.append(try await engine.metadata(of: document, page: PageIndex(i)).size.width)
        }
        XCTAssertEqual(widths, [100, 400, 200, 300])
    }

    func testRotateSetsPageRotation() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeSyntheticDocument(pageWidths: [100], in: dir, name: "a.pdf")

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)
        try await engine.apply(.rotate(PageIndex(0), by: .clockwise90), to: document)

        let metadata = try await engine.metadata(of: document, page: PageIndex(0))
        XCTAssertEqual(metadata.rotation, .clockwise90)
    }

    func testInsertFromSameDocumentDuplicatesPage() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeSyntheticDocument(pageWidths: [100, 200], in: dir, name: "a.pdf")

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)
        try await engine.apply(.insert(from: document, sourcePage: PageIndex(0), at: PageIndex(2)), to: document)

        let count = try await engine.pageCount(of: document)
        XCTAssertEqual(count, 3)
        let widths = try await [
            engine.metadata(of: document, page: PageIndex(0)).size.width,
            engine.metadata(of: document, page: PageIndex(1)).size.width,
            engine.metadata(of: document, page: PageIndex(2)).size.width,
        ]
        XCTAssertEqual(widths, [100, 200, 100])
    }

    /// Cross-document import (the "merge" building block per this file's
    /// header doc, and PDFEngineAPI's own `PageOrganizer.swift` doc comment
    /// on `.insert`) carries the source page's full resource graph via
    /// `FPDF_ImportPagesByIndex`, not just a content stream — verified here
    /// by confirming a text-bearing real fixture page's text survives the
    /// import (the task's "resource preservation on merge" requirement;
    /// pixel/font-rendering comparison is out of scope, same as every other
    /// engine-layer task this session verified at the layer it actually
    /// can).
    func testMergeImportsPageWithTextIntactFromAnotherDocument() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let destURL = try makeSyntheticDocument(pageWidths: [100], in: dir, name: "dest.pdf")
        let sourceURL = Self.repoRoot.appendingPathComponent("Fixtures/pdf-corpus/starter/irs-fw9.pdf")

        let engine = PDFiumEngine()
        let dest = try await engine.open(url: destURL)
        let source = try await engine.open(url: sourceURL)

        let sourceRuns = try await engine.textRuns(of: source, page: PageIndex(0))
        XCTAssertFalse(sourceRuns.isEmpty, "source fixture page should have extractable text to verify preservation")

        try await engine.apply(.insert(from: source, sourcePage: PageIndex(0), at: PageIndex(1)), to: dest)

        let count = try await engine.pageCount(of: dest)
        XCTAssertEqual(count, 2)
        let importedRuns = try await engine.textRuns(of: dest, page: PageIndex(1))
        XCTAssertFalse(importedRuns.isEmpty, "imported page should still have extractable text after cross-document import")
        XCTAssertEqual(importedRuns.map(\.text), sourceRuns.map(\.text))
    }

    // MARK: - Property-based round trip (Acceptance Criteria)

    /// 50 random ops (seeded, reproducible) against an 8-page synthetic
    /// document, mirrored against a plain-Swift model of the same
    /// operations. After save -> close -> reopen, every page's identity
    /// (width tag) and rotation must match the model exactly, and reopening
    /// itself must not throw (the "zero corruption" half of the criterion —
    /// a corrupted save would fail to reopen or report a wrong page count
    /// before we even get to per-page comparison).
    func testFiftyRandomPageOpsRoundTripMatchesModelWithZeroCorruption() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let initialWidths = (0..<8).map { Double(100 + $0) }
        let url = try makeSyntheticDocument(pageWidths: initialWidths, in: dir, name: "fuzz.pdf")

        var rng = SeededGenerator(seed: 0xC0FFEE)
        var model: [(width: Double, rotation: PageRotation)] = initialWidths.map { ($0, .none) }

        let engine = PDFiumEngine()
        let document = try await engine.open(url: url)

        for _ in 0..<50 {
            let count = model.count
            let opKind = Int.random(in: 0..<4, using: &rng)
            switch opKind {
            case 0 where count > 1: // delete
                let index = Int.random(in: 0..<count, using: &rng)
                try await engine.apply(.delete(PageIndex(index)), to: document)
                model.remove(at: index)

            case 1: // reorder
                let from = Int.random(in: 0..<count, using: &rng)
                let to = min(max(0, Int.random(in: 0..<count, using: &rng)), count - 1)
                try await engine.apply(.reorder(from: PageIndex(from), to: PageIndex(to)), to: document)
                let page = model.remove(at: from)
                model.insert(page, at: to)

            case 2: // rotate
                let index = Int.random(in: 0..<count, using: &rng)
                let rotation = [PageRotation.none, .clockwise90, .clockwise180, .clockwise270].randomElement(using: &rng)!
                try await engine.apply(.rotate(PageIndex(index), by: rotation), to: document)
                model[index].rotation = rotation

            default: // insert (self-duplicate) — also the fallback for opKind==0 when count==1
                let sourcePage = Int.random(in: 0..<count, using: &rng)
                let at = Int.random(in: 0...count, using: &rng)
                try await engine.apply(.insert(from: document, sourcePage: PageIndex(sourcePage), at: PageIndex(at)), to: document)
                model.insert(model[sourcePage], at: at)
            }
        }

        try await engine.save(document, mode: .fullRewrite, to: url)
        try await engine.close(document)

        let reopened = try await engine.open(url: url) // "reopening must not throw" = no corruption
        let finalCount = try await engine.pageCount(of: reopened)
        XCTAssertEqual(finalCount, model.count, "page count after round trip must match the modeled sequence")

        for index in 0..<model.count {
            let metadata = try await engine.metadata(of: reopened, page: PageIndex(index))
            // FPDF_GetPageWidth/Height's own doc comment: "changing the
            // rotation of |page| affects the return value" — a 90/270
            // rotation legitimately swaps which of the two comes back as
            // "width" vs. "height". Compare the unordered {width, height}
            // pair instead of `width` alone: every synthetic page here has
            // a distinct base width but the same 792pt base height, so the
            // pair is still a unique per-page identity regardless of which
            // axis PDFium reports rotated dimensions on.
            let actualPair = Set([metadata.size.width.rounded(), metadata.size.height.rounded()])
            let expectedPair = Set([model[index].width.rounded(), 792])
            XCTAssertEqual(actualPair, expectedPair, "page \(index) identity mismatch")
            XCTAssertEqual(metadata.rotation, model[index].rotation, "page \(index) rotation mismatch")
        }
    }
}

/// Deterministic seeded PRNG (xorshift64*) so the fuzz sequence above is
/// reproducible across runs/machines — `Int.random(using:)` needs a
/// `RandomNumberGenerator`, and Swift's default `SystemRandomNumberGenerator`
/// is deliberately non-reproducible. No third-party dependency: this is
/// ~10 lines of a well-known, public-domain algorithm (CLAUDE.md §17
/// "default answer to a new dependency is no").
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
