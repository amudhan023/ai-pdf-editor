import Foundation

/// In-memory `InferenceClient` for consumers' tests (CLAUDE.md §5's `Fake*`
/// naming: shipped in the API package, not a test-local `Mock*`). Returns
/// deterministic, structurally-valid stub responses — it does not run any
/// real model, so callers relying on this for accuracy benches must not
/// (the accuracy bar is InferenceHost's real adapters' job, P1-13+).
public actor FakeInferenceClient: InferenceClient {
    public init() {}

    public func ocr(_ request: OCRRequest) async throws -> OCRResponse {
        guard !request.imageData.isEmpty else {
            throw InferenceError.adapterFailure(reason: "empty imageData")
        }
        return OCRResponse(regions: [
            OCRTextRegion(
                text: "FAKE_OCR_TEXT",
                boundingBox: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                confidence: 0.99
            )
        ])
    }

    public func classify(_ request: ClassifyRequest) async throws -> ClassifyResponse {
        guard let first = request.candidateLabels.first else {
            throw InferenceError.capabilityUnavailable(.classify, .appleSilicon)
        }
        return ClassifyResponse(label: first, confidence: 0.9)
    }

    public func extractEntities(_ request: ExtractEntitiesRequest) async throws -> ExtractEntitiesResponse {
        let entities = request.schema.map { type in
            ExtractedEntity(type: type, value: "FAKE_VALUE", startOffset: 0, length: 0, confidence: 0.8)
        }
        return ExtractEntitiesResponse(entities: entities)
    }

    public func embed(_ request: EmbedRequest) async throws -> EmbedResponse {
        EmbedResponse(vectors: request.texts.map { Self.deterministicVector(for: $0) })
    }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResponse {
        if let first = request.candidates.first {
            return GenerateResponse(text: first, chosenCandidateIndex: 0)
        }
        return GenerateResponse(text: "FAKE_GENERATED: \(request.prompt.prefix(32))", chosenCandidateIndex: nil)
    }

    /// FNV-1a-derived, dependency-free stand-in for a real embedding —
    /// same-text-same-vector / different-text-different-vector only, no
    /// semantic meaning. Identical spirit to `VaultAPI.FieldValue`'s
    /// `stableFingerprint()`.
    private static func deterministicVector(for text: String, dimensions: Int = 8) -> [Float] {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return (0..<dimensions).map { index in
            let shifted = hash &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
            return Float(shifted % 1000) / 1000.0
        }
    }
}
