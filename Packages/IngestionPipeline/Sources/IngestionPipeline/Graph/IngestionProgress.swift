import Foundation

/// Stage lifecycle events for progress reporting. Names/messages are stage
/// identifiers and typed error summaries only — never document content or
/// extracted values (CLAUDE.md §16).
public enum IngestionProgressEvent: Sendable, Equatable {
    case stageStarted(String)
    case stageCompleted(String)
    case stageFailed(String, debugDescription: String)
}

/// The runner's final result: candidates from every extractor that
/// succeeded, plus which ones failed (if any) and why — a failed extractor
/// never discards a successful sibling's output (per-stage isolation).
public struct IngestionResult: Sendable, Equatable {
    public let classification: DocumentClassification
    public let candidates: [ExtractionCandidate]
    public let failedExtractors: [String: IngestionError]

    public init(
        classification: DocumentClassification,
        candidates: [ExtractionCandidate],
        failedExtractors: [String: IngestionError] = [:]
    ) {
        self.classification = classification
        self.candidates = candidates
        self.failedExtractors = failedExtractors
    }
}
