import Foundation

/// The seam extractor tasks (P2-09/P2-10) plug into. Each extractor is
/// independent — the runner isolates failures per-extractor (Requirements:
/// "per-stage error isolation, bad stage != dead pipeline") and runs them
/// concurrently (Background: "P2-09/10 are parallel-friendly because of
/// this seam"). See `Packages/IngestionPipeline/CLAUDE.md`'s stage-authoring
/// guide for how to add one.
public protocol ExtractorStage: Sendable {
    /// Stable identifier for provenance attribution and error reporting —
    /// never document content (CLAUDE.md §16).
    var name: String { get }

    /// Whether this extractor applies to a classified document — lets the
    /// runner skip extractors that don't match rather than running every
    /// registered extractor against every document.
    func supports(_ classification: DocumentClassification) -> Bool

    func extract(from document: NormalizedDocument, classification: DocumentClassification) async throws -> [ExtractionCandidate]
}
