import XCTest
@testable import PDFEngineAPI

/// Proves `FakePDFEngine` passes the shared conformance suite — the same
/// suite a real PDFium-backed engine must pass later (this task's Testing
/// Requirements).
final class FakePDFEngineConformanceTests: XCTestCase {
    func testPageRendererConformance() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument(pageCount: 3)
        try await PDFEngineConformanceSuite.verifyPageRenderer(engine, document: document)
    }

    func testAnnotationStoreConformance() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument()
        try await PDFEngineConformanceSuite.verifyAnnotationStore(engine, document: document, page: PageIndex(0))
    }

    func testFormModelConformance() async throws {
        let engine = FakePDFEngine()
        let document = await engine.seedDocument()
        try await engine.seedFields([
            FormField(name: "applicant.fullName", page: PageIndex(0), rect: PDFRect(x: 0, y: 0, width: 200, height: 20), kind: .text, tabOrder: 0)
        ], for: document)
        try await PDFEngineConformanceSuite.verifyFormModel(engine, document: document)
    }
}
