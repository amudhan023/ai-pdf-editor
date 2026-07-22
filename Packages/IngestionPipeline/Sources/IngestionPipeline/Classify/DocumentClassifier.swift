import Foundation
import InferenceAPI

/// Wraps `InferenceClient.classify` with the closed `DocumentType` label
/// set. Never throws: an endpoint failure or a low-confidence result both
/// degrade to `.generic` with `isFallback: true` rather than propagating an
/// error up into the pipeline (Acceptance Criteria: "misclassification
/// routes to generic extractor, never a crash").
public struct DocumentClassifier: Sendable {
    /// Below this, a real-but-uncertain classification is treated the same
    /// as an unavailable endpoint: route to generic rather than act on a
    /// low-confidence label. Bench-tunable, not a magic number to bury —
    /// see `Packages/IngestionPipeline/CLAUDE.md`.
    public static let lowConfidenceThreshold = 0.5

    private let inferenceClient: InferenceClient

    public init(inferenceClient: InferenceClient) {
        self.inferenceClient = inferenceClient
    }

    public func classify(_ page: NormalizedPage) async -> DocumentClassification {
        guard let imageData = page.imageData else {
            return DocumentClassification(type: .generic, confidence: 0, isFallback: true)
        }
        let request = ClassifyRequest(
            imageData: imageData,
            candidateLabels: DocumentType.allCases.map(\.rawValue),
            priority: .background
        )
        guard let response = try? await inferenceClient.classify(request),
              let type = DocumentType(rawValue: response.label) else {
            return DocumentClassification(type: .generic, confidence: 0, isFallback: true)
        }
        guard response.confidence >= Self.lowConfidenceThreshold else {
            return DocumentClassification(type: .generic, confidence: response.confidence, isFallback: true)
        }
        return DocumentClassification(type: type, confidence: response.confidence)
    }
}
