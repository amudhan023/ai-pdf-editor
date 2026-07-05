import XCTest
@testable import InferenceAPI

/// Every DTO that crosses XPC must round-trip through JSON losslessly
/// (root CLAUDE.md §4: "Sendable/Codable for anything crossing XPC").
final class CodableRoundTripTests: XCTestCase {
    private func assertRoundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }

    func testOCRRoundTrip() throws {
        try assertRoundTrip(OCRRequest(imageData: Data([0x01, 0x02]), priority: .background))
        try assertRoundTrip(OCRResponse(regions: [
            OCRTextRegion(text: "Jane Doe", boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05), confidence: 0.95)
        ]))
    }

    func testClassifyRoundTrip() throws {
        try assertRoundTrip(ClassifyRequest(imageData: Data([0x01]), candidateLabels: ["passport", "resume"]))
        try assertRoundTrip(ClassifyResponse(label: "passport", confidence: 0.87))
    }

    func testExtractEntitiesRoundTrip() throws {
        try assertRoundTrip(ExtractEntitiesRequest(text: "some text", schema: ["identity.date_of_birth"]))
        try assertRoundTrip(ExtractEntitiesResponse(entities: [
            ExtractedEntity(type: "identity.date_of_birth", value: "1990-01-01", startOffset: 5, length: 10, confidence: 0.9)
        ]))
    }

    func testEmbedRoundTrip() throws {
        try assertRoundTrip(EmbedRequest(texts: ["Full Legal Name"]))
        try assertRoundTrip(EmbedResponse(vectors: [[0.1, 0.2, 0.3]]))
    }

    func testGenerateRoundTrip() throws {
        try assertRoundTrip(GenerateRequest(prompt: "pick a format", candidates: ["A", "B"]))
        try assertRoundTrip(GenerateResponse(text: "A", chosenCandidateIndex: 0))
        try assertRoundTrip(GenerateResponse(text: "free-form", chosenCandidateIndex: nil))
    }

    func testModelManifestRoundTrip() throws {
        try assertRoundTrip(ModelManifest(
            modelID: "ocr-vision-v1", capability: .ocr, version: "1.0.0", hardwareTier: .appleSilicon,
            sha256Checksum: "abc123", signature: Data([0x01, 0x02, 0x03]), estimatedMemoryBytes: 50_000_000
        ))
    }

    func testInferenceErrorRoundTrip() throws {
        try assertRoundTrip(InferenceError.capabilityUnavailable(.ocr, .intel))
        try assertRoundTrip(InferenceError.modelPackUnverified(reason: "checksum mismatch"))
    }
}
