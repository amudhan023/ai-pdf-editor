import XCTest
import PDFEngineAPI
@testable import IngestionPipeline

final class NormalizerTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ data: Data, name: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    func testTextFileNormalizesToSinglePageWithText() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let url = write("hello world".data(using: .utf8)!, name: "note.txt")

        let doc = try await normalizer.normalize(fileURL: url)

        XCTAssertEqual(doc.sourceFormat, .txt)
        XCTAssertEqual(doc.pages.count, 1)
        XCTAssertEqual(doc.pages[0].text, "hello world")
        XCTAssertNil(doc.pages[0].imageData)
    }

    func testPDFNormalizesEveryPageWithRasterizedImageData() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine, textEditor: engine)
        let handle = await engine.seedDocument(pageCount: 3)
        let url = write("%PDF-1.4 fake".data(using: .utf8)!, name: "doc.pdf")

        let doc = try await normalizer.normalize(fileURL: url, document: handle)

        XCTAssertEqual(doc.sourceFormat, .pdf)
        XCTAssertEqual(doc.pages.count, 3)
        for page in doc.pages {
            XCTAssertNotNil(page.imageData, "every PDF page should get a rasterized image for classification")
            XCTAssertEqual(page.imageData?.prefix(8).map { $0 }, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        }
    }

    func testPDFPageWithTextLayerPopulatesTextFromTextEditor() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine, textEditor: engine)
        let handle = await engine.seedDocument(pageCount: 1)
        try await engine.seedTextRuns(
            [TextRun(page: PageIndex(0), text: "Invoice #4471", boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10), fontSize: 12)],
            for: handle
        )
        let url = write("%PDF-1.4 fake".data(using: .utf8)!, name: "doc.pdf")

        let doc = try await normalizer.normalize(fileURL: url, document: handle)

        XCTAssertEqual(doc.pages[0].text, "Invoice #4471")
    }

    func testPDFWithoutOpenHandleThrowsEngineError() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let url = write("%PDF-1.4 fake".data(using: .utf8)!, name: "doc.pdf")

        await XCTAssertThrowsErrorAsync(try await normalizer.normalize(fileURL: url)) { error in
            guard let typed = error as? IngestionError, case .engine = typed else {
                return XCTFail("expected .engine, got \(error)")
            }
        }
    }

    func testImagePassesThroughAsIsByMagicBytes() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        // Real JPEG magic bytes with a wrong extension - magic-byte
        // sniffing must win over the (misleading) file extension.
        let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0), count: 16))
        let url = write(jpegBytes, name: "photo.dat")

        let doc = try await normalizer.normalize(fileURL: url)

        XCTAssertEqual(doc.sourceFormat, .jpeg)
        XCTAssertEqual(doc.pages[0].imageData, jpegBytes)
    }

    // DOCX/RTF normalization (ADR-017) is covered by DocxRtfExtractionTests.swift,
    // including the corrupt-input typed-error path this file used to assert
    // as "unsupported" before that ADR landed.

    func testOversizedInputIsRejectedWithoutReadingIt() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        // Sparse file: seek past the limit and write one byte, so the file
        // reports a large size without this test actually allocating/writing
        // 200MB - the assertion is that Normalizer rejects by *size*, not
        // that it read the whole (mostly-sparse) content.
        let url = tempDir.appendingPathComponent("huge.jpg")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: UInt64(Normalizer.maxInputBytes + 1))
        handle.write(Data([0x00]))
        try handle.close()

        await XCTAssertThrowsErrorAsync(try await normalizer.normalize(fileURL: url)) { error in
            guard let typed = error as? IngestionError, case .sizeLimitExceeded = typed else {
                return XCTFail("expected .sizeLimitExceeded, got \(error)")
            }
        }
    }

    func testEmptyImageFileIsCorruptInput() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let url = write(Data(), name: "empty.png")

        await XCTAssertThrowsErrorAsync(try await normalizer.normalize(fileURL: url)) { error in
            guard let typed = error as? IngestionError, case .corruptInput = typed else {
                return XCTFail("expected .corruptInput, got \(error)")
            }
        }
    }
}

/// `XCTAssertThrowsError` has no async overload in this toolchain's XCTest;
/// small local helper rather than a new dependency.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
