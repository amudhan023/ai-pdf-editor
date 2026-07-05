import Foundation
import InferenceAPI

/// Availability probe + stub for the on-device LLM path (Apple Foundation
/// Models when present, else a downloadable pack — ARCHITECTURE.md §7.1).
/// `isFoundationModelAvailable` is a placeholder returning `false`: wiring
/// the real `FoundationModels` framework's `SystemLanguageModel.availability`
/// check is out of this stub's scope and left for the task that consumes
/// it, so the gap is documented rather than silently assumed away.
public struct FoundationModelsAdapter: Sendable {
    public init() {}

    public var isFoundationModelAvailable: Bool { false }

    public func generate(_ request: GenerateRequest, manifest: ModelManifest) async throws -> GenerateResponse {
        if let first = request.candidates.first {
            return GenerateResponse(text: first, chosenCandidateIndex: 0)
        }
        return GenerateResponse(text: "STUB_GENERATED", chosenCandidateIndex: nil)
    }
}
