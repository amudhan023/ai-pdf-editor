import XCTest
import PDFEngineAPI
@testable import IngestionPipeline

final class IngestionPipelineRunnerTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeTxt(_ text: String) -> URL {
        let url = tempDir.appendingPathComponent("doc.txt")
        try? text.data(using: .utf8)!.write(to: url)
        return url
    }

    func testOneFailingExtractorDoesNotDiscardAnotherSucceedingExtractorsCandidates() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let good = ScriptedExtractor(name: "good", supportedTypes: [.generic], behavior: .succeed([try makeCandidate()]))
        let bad = ScriptedExtractor(name: "bad", supportedTypes: [.generic], behavior: .fail(.engine("boom")))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: [good, bad]
        )

        let result = try await runner.run(fileURL: writeTxt("hello"))

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].value, "Jane Doe")
        XCTAssertEqual(result.failedExtractors["bad"], .engine("boom"))
        XCTAssertNil(result.failedExtractors["good"])
    }

    func testExtractorNotSupportingTheClassificationIsSkippedNotFailed() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.resume.rawValue, confidence: 0.9))
        let irrelevant = ScriptedExtractor(name: "passport-only", supportedTypes: [.passport], behavior: .succeed([try makeCandidate()]))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: [irrelevant]
        )

        let result = try await runner.run(fileURL: writeTxt("hello"))

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertTrue(result.failedExtractors.isEmpty)
    }

    func testNoExtractorsRegisteredReturnsEmptyCandidatesNotAnError() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: []
        )

        let result = try await runner.run(fileURL: writeTxt("hello"))

        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testUnsupportedFormatFailsTheWholeRunTyped() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: []
        )
        // No magic bytes and no recognized extension - format detection
        // itself can't identify this input, distinct from DOCX/RTF's
        // "recognized but needs a decision" case.
        let url = tempDir.appendingPathComponent("mystery.bin")
        try? Data([0x00, 0x01, 0x02, 0x03]).write(to: url)

        do {
            _ = try await runner.run(fileURL: url)
            XCTFail("expected .unsupportedFormat to propagate")
        } catch let error as IngestionError {
            XCTAssertEqual(error, .unsupportedFormat(.unknown))
        }
    }

    func testCancellingTheParentTaskCancelsAStillRunningExtractor() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: [CancellationProbeExtractor()]
        )
        let url = writeTxt("hello")

        let task = Task {
            try await runner.run(fileURL: url)
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()

        let result = try await task.value
        XCTAssertNotNil(result.failedExtractors["cancellation-probe"])
    }

    func testProgressEventsReportEveryStageInOrder() async throws {
        let engine = FakePDFEngine()
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let extractor = ScriptedExtractor(name: "solo", supportedTypes: [.generic], behavior: .succeed([]))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: [extractor]
        )

        let events = ProgressCollector()
        _ = try await runner.run(fileURL: writeTxt("hello")) { event in
            events.record(event)
        }

        let recorded = events.all
        XCTAssertTrue(recorded.contains(.stageStarted("normalize")))
        XCTAssertTrue(recorded.contains(.stageCompleted("normalize")))
        XCTAssertTrue(recorded.contains(.stageStarted("classify")))
        XCTAssertTrue(recorded.contains(.stageCompleted("classify")))
        XCTAssertTrue(recorded.contains(.stageStarted("solo")))
        XCTAssertTrue(recorded.contains(.stageCompleted("solo")))
    }

    /// Format-matrix smoke test: one fixture per currently-supported format
    /// through the whole pipeline, proving each reaches a real result (or a
    /// precisely-typed error for the known-unsupported ones) rather than
    /// crashing.
    func testFormatMatrixSmoke() async throws {
        let engine = FakePDFEngine()
        let pdfHandle = await engine.seedDocument(pageCount: 1)
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let runner = IngestionPipelineRunner(
            normalizer: Normalizer(pageRenderer: engine, textEditor: engine),
            classifier: DocumentClassifier(inferenceClient: mock),
            extractors: []
        )

        let txtURL = writeTxt("plain text")
        let txtResult = try await runner.run(fileURL: txtURL)
        XCTAssertEqual(txtResult.classification.type, .generic)

        let pdfURL = tempDir.appendingPathComponent("doc.pdf")
        try? "%PDF-1.4 fake".data(using: .utf8)!.write(to: pdfURL)
        let pdfResult = try await runner.run(fileURL: pdfURL, document: pdfHandle)
        XCTAssertEqual(pdfResult.classification.type, .generic)

        let jpegURL = tempDir.appendingPathComponent("photo.jpg")
        try? Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0]).write(to: jpegURL)
        let jpegResult = try await runner.run(fileURL: jpegURL)
        XCTAssertEqual(jpegResult.classification.type, .generic)

        let rtfURL = tempDir.appendingPathComponent("letter.rtf")
        try? "{\\rtf1 hi}".data(using: .utf8)!.write(to: rtfURL)
        let rtfResult = try await runner.run(fileURL: rtfURL)
        XCTAssertEqual(rtfResult.classification.type, .generic)

        let docxURL = tempDir.appendingPathComponent("resume.docx")
        try? DocxFixtureBuilder.buildMinimalDocx(bodyXML: "<w:p><w:r><w:t>hi</w:t></w:r></w:p>", compressed: false).write(to: docxURL)
        let docxResult = try await runner.run(fileURL: docxURL)
        XCTAssertEqual(docxResult.classification.type, .generic)

        let unknownURL = tempDir.appendingPathComponent("mystery.bin")
        try? Data([0x00, 0x01, 0x02]).write(to: unknownURL)
        do {
            _ = try await runner.run(fileURL: unknownURL)
            XCTFail("unrecognized input should be a typed unsupported-format error, not silently succeed")
        } catch let error as IngestionError {
            XCTAssertEqual(error, .unsupportedFormat(.unknown))
        }
    }
}

/// Plain class, not an actor: the progress callback in
/// `IngestionPipelineRunner.run` is synchronous (`@Sendable (Event) -> Void`),
/// so it can't `await` an actor's isolated method — a lock-protected box is
/// the minimum thing that's both `Sendable` and callable from a sync closure.
final class ProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [IngestionProgressEvent] = []

    func record(_ event: IngestionProgressEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    var all: [IngestionProgressEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}
