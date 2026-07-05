import Foundation
import InferenceAPI

/// Stub for the Core ML-backed classify/extractEntities/embed adapters —
/// real models land in later tasks (P1-14 embeddings; classification/NER
/// in Phase 2). Returns structurally valid, deterministic results.
public struct CoreMLAdapter: Sendable {
    public init() {}

    public func classify(_ request: ClassifyRequest, manifest: ModelManifest) async throws -> ClassifyResponse {
        guard let first = request.candidateLabels.first else {
            throw InferenceError.capabilityUnavailable(.classify, manifest.hardwareTier)
        }
        return ClassifyResponse(label: first, confidence: 0.5)
    }

    public func extractEntities(_ request: ExtractEntitiesRequest, manifest: ModelManifest) async throws -> ExtractEntitiesResponse {
        ExtractEntitiesResponse(entities: request.schema.map { type in
            ExtractedEntity(type: type, value: "STUB_VALUE", startOffset: 0, length: 0, confidence: 0.5)
        })
    }

    public func embed(_ request: EmbedRequest, manifest: ModelManifest) async throws -> EmbedResponse {
        EmbedResponse(vectors: request.texts.map { _ in Array(repeating: Float(0), count: 8) })
    }
}
