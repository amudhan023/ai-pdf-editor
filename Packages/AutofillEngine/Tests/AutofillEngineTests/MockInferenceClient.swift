import Foundation
import InferenceAPI

/// Test-local double (`Mock*`, not the shipped `Fake*`) that lets tests
/// control `generate`'s latency/failure independent of
/// `FakeInferenceClient`'s fixed always-succeeds behavior — needed to
/// exercise `SemanticMatcher`'s hard-timeout and
/// generate-endpoint-unavailable degradation paths deterministically.
/// `embed` always delegates to `FakeInferenceClient` (its deterministic
/// hash-based vectors are sufficient for these tests; only `generate`'s
/// behavior needs to vary).
actor MockInferenceClient: InferenceClient {
    enum GenerateBehavior {
        case respond(GenerateResponse)
        case unavailable
        /// Sleeps far longer than any test's configured timeout, so the
        /// caller's `Task.sleep` race always wins — proves the timeout is
        /// real, not just "the fake happened to answer fast."
        case neverReturns
    }

    private let inner = FakeInferenceClient()
    private let generateBehavior: GenerateBehavior

    init(generate: GenerateBehavior) {
        self.generateBehavior = generate
    }

    func ocr(_ request: OCRRequest) async throws -> OCRResponse { try await inner.ocr(request) }
    func classify(_ request: ClassifyRequest) async throws -> ClassifyResponse { try await inner.classify(request) }
    func extractEntities(_ request: ExtractEntitiesRequest) async throws -> ExtractEntitiesResponse {
        try await inner.extractEntities(request)
    }
    func embed(_ request: EmbedRequest) async throws -> EmbedResponse { try await inner.embed(request) }

    func generate(_ request: GenerateRequest) async throws -> GenerateResponse {
        switch generateBehavior {
        case .respond(let response):
            return response
        case .unavailable:
            throw InferenceError.capabilityUnavailable(.generate, .intel)
        case .neverReturns:
            try await Task.sleep(for: .seconds(3600))
            throw InferenceError.requestCancelled
        }
    }
}
