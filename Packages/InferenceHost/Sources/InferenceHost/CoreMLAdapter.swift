import Foundation
import InferenceAPI

/// `classify`/`extractEntities` remain stubs (Phase 2 lands their real
/// models); `embed` is real as of P1-14 — see `NLEmbeddingProvider` for why
/// it's NLEmbedding-backed rather than a vendored Core ML pack. `manifest`
/// is unused by `embed` on purpose: the embedding backend is an OS
/// capability, not registry-loaded packData.
public struct CoreMLAdapter: Sendable {
    private let embeddingProvider: NLEmbeddingProvider

    public init(embeddingProvider: NLEmbeddingProvider = NLEmbeddingProvider()) {
        self.embeddingProvider = embeddingProvider
    }

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
        let vectors = try await embeddingProvider.embed(request.texts)
        return EmbedResponse(vectors: vectors)
    }
}
