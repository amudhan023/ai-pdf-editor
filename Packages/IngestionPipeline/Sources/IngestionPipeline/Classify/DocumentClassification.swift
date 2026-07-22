import Foundation

/// The closed set of document types the classifier chooses among (task's
/// own Requirements wording — constrained choice, CLAUDE.md §19).
/// `.generic` is both a real classification outcome and the fallback target
/// for low-confidence/unavailable classification.
public enum DocumentType: String, Sendable, Equatable, CaseIterable {
    case passport
    case license
    case resume
    case filledForm = "filled-form"
    case certificate
    case utilityBill = "utility-bill"
    case generic
}

public struct DocumentClassification: Sendable, Equatable {
    public let type: DocumentType
    public let confidence: Double
    /// `true` when this is a real model result; `false` when the endpoint
    /// was unavailable/errored and this is the graceful `.generic` fallback
    /// (Acceptance Criteria: "misclassification routes to generic
    /// extractor, never a crash").
    public let isFallback: Bool

    public init(type: DocumentType, confidence: Double, isFallback: Bool = false) {
        self.type = type
        self.confidence = confidence
        self.isFallback = isFallback
    }
}
