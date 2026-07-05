import Foundation

/// Engine-neutral inference operations — every AI feature is a typed
/// endpoint here; call sites never name a model file (CLAUDE.md §19).
public protocol InferenceClient: Sendable {
    func ocr(_ request: OCRRequest) async throws -> OCRResponse
    func classify(_ request: ClassifyRequest) async throws -> ClassifyResponse
    func extractEntities(_ request: ExtractEntitiesRequest) async throws -> ExtractEntitiesResponse
    func embed(_ request: EmbedRequest) async throws -> EmbedResponse
    func generate(_ request: GenerateRequest) async throws -> GenerateResponse
}
