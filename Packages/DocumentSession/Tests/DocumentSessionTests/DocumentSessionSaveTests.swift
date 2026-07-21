import XCTest
import PDFEngineAPI
@testable import DocumentSession

/// Covers P1-22: `DocumentSession.save()` must obtain serialized bytes via
/// the engine and commit them through `AtomicSaver`'s real write-temp ->
/// validate -> atomic-replace path, not a stub. Uses `MockPersistingEngine`
/// (see its doc comment for why real `PDFiumEngine` can't be used here) —
/// `DocEngineHost`'s own P1-21 tests already cover the equivalent round
/// trip against the real engine.
final class DocumentSessionSaveTests: XCTestCase {
    private func makeWorkspace() throws -> (original: URL, backups: URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = dir.appendingPathComponent("doc.pdf")
        try MockPersistingEngine.writeInitialDocument(at: original)
        return (original, dir.appendingPathComponent("backups"))
    }

    func testOpenMutateSaveReopenPersistsTheAnnotation() async throws {
        let (original, backups) = try makeWorkspace()
        let engine = MockPersistingEngine()
        let saver = AtomicSaver(engine: engine, backupDirectory: backups)

        let session = DocumentSession(lifecycle: engine, renderer: engine, annotationStore: engine, atomicSaver: saver)
        try await session.open(url: original)

        let annotation = Annotation(page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10))
        try await session.addAnnotation(annotation)
        try await session.save(mode: .fullRewrite)
        try await session.close()

        let reopened = DocumentSession(lifecycle: engine, renderer: engine, annotationStore: engine, atomicSaver: saver)
        try await reopened.open(url: original)
        let annotations = try await reopened.annotations(page: PageIndex(0))

        XCTAssertEqual(annotations.map(\.id), [annotation.id])
    }

    func testSaveWithoutAtomicSaverWiredThrowsUnsupportedFeature() async throws {
        let engine = MockPersistingEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine, annotationStore: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/unused.pdf"))

        do {
            try await session.save()
            XCTFail("expected .unsupportedFeature when no AtomicSaver is wired")
        } catch DocumentSessionError.engine(.unsupportedFeature) {
            // expected
        }
    }

    func testSavePropagatesEngineIOFailureAsTypedError() async throws {
        let (original, backups) = try makeWorkspace()
        let engine = FailingSaveEngine()
        let saver = AtomicSaver(engine: engine, backupDirectory: backups)
        let session = DocumentSession(lifecycle: engine, renderer: engine, atomicSaver: saver)
        try await session.open(url: original)

        do {
            try await session.save()
            XCTFail("expected the engine's ioFailure to propagate")
        } catch DocumentSessionError.engine(.ioFailure) {
            // expected: the engine failure surfaces untouched, not
            // generalized into .saveFailed or swallowed.
        }
    }
}

/// Test-local mock whose `save` always fails, proving `DocumentSession.save()`
/// surfaces a `PDFEngineError.ioFailure` from the engine as-is rather than
/// converting it to the atomic-replace error path.
private actor FailingSaveEngine: DocumentLifecycle, PageRenderer {
    func open(url: URL) async throws -> DocumentHandle { DocumentHandle() }
    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {
        throw PDFEngineError.ioFailure("disk full (simulated)")
    }
    func close(_ document: DocumentHandle) async throws {}
    func pageCount(of document: DocumentHandle) async throws -> Int { 1 }
    func metadata(of document: DocumentHandle, page: PageIndex) async throws -> PageMetadata {
        PageMetadata(index: page, size: PageSize(width: 612, height: 792), rotation: .none)
    }
    func renderTile(of document: DocumentHandle, request: TileRenderRequest) async throws -> RenderedTile {
        RenderedTile(request: request, pixelWidth: 1, pixelHeight: 1, pixelData: Data(count: 4))
    }
}
