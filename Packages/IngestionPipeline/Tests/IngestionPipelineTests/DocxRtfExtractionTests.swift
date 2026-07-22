import XCTest
import PDFEngineAPI
@testable import IngestionPipeline

final class DocxRtfExtractionTests: XCTestCase {
    // MARK: - DOCX

    func testStoredDocxExtractsRunTextFromDocumentXML() throws {
        let body = "<w:p><w:r><w:t>Hello</w:t></w:r><w:r><w:t>world</w:t></w:r></w:p>"
        let docx = DocxFixtureBuilder.buildMinimalDocx(bodyXML: body, compressed: false)

        let text = try DocxTextExtractor.extractPlainText(from: docx)

        XCTAssertEqual(text, "Hello world")
    }

    func testDeflateCompressedDocxExtractsRunText() throws {
        let body = "<w:p><w:r><w:t>Compressed</w:t></w:r><w:r><w:t>entry</w:t></w:r></w:p>"
        let docx = DocxFixtureBuilder.buildMinimalDocx(bodyXML: body, compressed: true)

        let text = try DocxTextExtractor.extractPlainText(from: docx)

        XCTAssertEqual(text, "Compressed entry")
    }

    func testTruncatedDocxThrowsTypedErrorNotCrash() {
        let docx = DocxFixtureBuilder.buildMinimalDocx(bodyXML: "<w:p><w:r><w:t>Hi</w:t></w:r></w:p>", compressed: false)
        let truncated = docx.prefix(docx.count - 10) // cut off the tail of the entry data

        XCTAssertThrowsError(try DocxTextExtractor.extractPlainText(from: Data(truncated))) { error in
            guard let typed = error as? IngestionError, case .corruptInput(.docx, _) = typed else {
                return XCTFail("expected .corruptInput(.docx, _), got \(error)")
            }
        }
    }

    func testDocxMissingDocumentXmlThrowsTypedError() {
        // A well-formed local file header for an unrelated entry name -
        // proves the "not found" path is a typed error, not a crash.
        let zip = DocxFixtureBuilder.buildMinimalDocx(bodyXML: "<w:p/>", compressed: false, entryName: "word/styles.xml")

        XCTAssertThrowsError(try DocxTextExtractor.extractPlainText(from: zip)) { error in
            guard let typed = error as? IngestionError, case .corruptInput(.docx, let reason) = typed else {
                return XCTFail("expected .corruptInput(.docx, _), got \(error)")
            }
            XCTAssertTrue(reason.contains("not found"))
        }
    }

    // MARK: - RTF

    func testSimpleRtfExtractsPlainText() throws {
        let rtf = Data("{\\rtf1\\ansi\\deff0 Hello world}".utf8)

        let text = try RtfTextExtractor.extractPlainText(from: rtf)

        XCTAssertEqual(text, "Hello world")
    }

    func testRtfSkipsFontTableAndColorTableDestinations() throws {
        let rtf = Data("""
        {\\rtf1\\ansi{\\fonttbl{\\f0 Times New Roman;}}{\\colortbl;\\red0\\green0\\blue0;}Visible text only}
        """.utf8)

        let text = try RtfTextExtractor.extractPlainText(from: rtf)

        XCTAssertEqual(text, "Visible text only")
    }

    func testRtfHexEscapeAndParControlWord() throws {
        let rtf = Data("{\\rtf1 caf\\'e9\\par next line}".utf8)

        let text = try RtfTextExtractor.extractPlainText(from: rtf)

        XCTAssertEqual(text, "caf\u{e9}\nnext line")
    }

    func testRtfIgnorableDestinationIsSkipped() throws {
        let rtf = Data("{\\rtf1 before {\\*\\generator Some Tool} after}".utf8)

        let text = try RtfTextExtractor.extractPlainText(from: rtf)

        XCTAssertEqual(text, "before after")
    }

    func testUnbalancedRtfBracesThrowsTypedError() {
        let rtf = Data("{\\rtf1 unterminated".utf8)

        XCTAssertThrowsError(try RtfTextExtractor.extractPlainText(from: rtf)) { error in
            guard let typed = error as? IngestionError, case .corruptInput(.rtf, _) = typed else {
                return XCTFail("expected .corruptInput(.rtf, _), got \(error)")
            }
        }
    }

    // MARK: - Wired through Normalizer

    func testNormalizerProducesTextPageForDocx() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let docx = DocxFixtureBuilder.buildMinimalDocx(bodyXML: "<w:p><w:r><w:t>Resume</w:t></w:r></w:p>", compressed: false)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("resume.docx")
        try docx.write(to: url)

        let doc = try await normalizer.normalize(fileURL: url)

        XCTAssertEqual(doc.sourceFormat, .docx)
        XCTAssertEqual(doc.pages[0].text, "Resume")
    }

    func testNormalizerProducesTextPageForRtf() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("letter.rtf")
        try Data("{\\rtf1 Dear Sir}".utf8).write(to: url)

        let doc = try await normalizer.normalize(fileURL: url)

        XCTAssertEqual(doc.sourceFormat, .rtf)
        XCTAssertEqual(doc.pages[0].text, "Dear Sir")
    }

    /// Acceptance Criteria: "Pipeline handles a corrupt DOCX... gracefully."
    func testNormalizerSurfacesCorruptDocxAsTypedErrorNotCrash() async throws {
        let engine = FakePDFEngine()
        let normalizer = Normalizer(pageRenderer: engine)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("corrupt.docx")
        // Real ZIP signature (so format detection says .docx) followed by
        // garbage - not a valid local file header past the signature.
        try Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF, 0xFF]).write(to: url)

        do {
            _ = try await normalizer.normalize(fileURL: url)
            XCTFail("expected a typed error")
        } catch let error as IngestionError {
            guard case .corruptInput(.docx, _) = error else {
                return XCTFail("expected .corruptInput(.docx, _), got \(error)")
            }
        }
    }
}
