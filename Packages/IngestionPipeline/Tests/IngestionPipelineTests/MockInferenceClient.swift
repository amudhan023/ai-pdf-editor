import Foundation
import InferenceAPI

/// Test-local double (`Mock*`, not the shipped `Fake*`) that returns a
/// configurable, deterministic `ClassifyResponse` rather than
/// `FakeInferenceClient`'s always-echo-the-first-candidate behavior —
/// needed to exercise golden-set/degradation cases (a specific label at a
/// specific confidence, or a thrown error) that the shipped fake can't
/// produce.
actor MockInferenceClient: InferenceClient {
    enum Behavior {
        case respond(label: String, confidence: Double)
        case fail
    }

    private var behavior: Behavior
    private(set) var receivedRequests: [ClassifyRequest] = []

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func ocr(_ request: OCRRequest) async throws -> OCRResponse {
        OCRResponse(regions: [])
    }

    func classify(_ request: ClassifyRequest) async throws -> ClassifyResponse {
        receivedRequests.append(request)
        switch behavior {
        case .respond(let label, let confidence):
            return ClassifyResponse(label: label, confidence: confidence)
        case .fail:
            throw InferenceError.adapterFailure(reason: "mock configured to fail")
        }
    }

    func extractEntities(_ request: ExtractEntitiesRequest) async throws -> ExtractEntitiesResponse {
        ExtractEntitiesResponse(entities: [])
    }

    func embed(_ request: EmbedRequest) async throws -> EmbedResponse {
        EmbedResponse(vectors: [])
    }

    func generate(_ request: GenerateRequest) async throws -> GenerateResponse {
        GenerateResponse(text: "", chosenCandidateIndex: nil)
    }
}
