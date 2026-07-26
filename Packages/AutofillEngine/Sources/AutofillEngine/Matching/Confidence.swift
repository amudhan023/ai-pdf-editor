import Foundation

/// Per-candidate confidence tier (P2-03: "calibrated confidence
/// (high/medium/low) with per-rung attribution"). See
/// `docs/specs/matching-confidence.md` for the full reasoning; thresholds
/// here are bench-tunable, not load-bearing constants.
public enum MatchConfidence: String, Sendable, Equatable, CaseIterable {
    case low
    case medium
    case high
}

enum ConfidenceCalibration {
    /// Embedding cosine-similarity thresholds. `FakeInferenceClient`'s
    /// hash-based stand-in vectors have no semantic meaning, so these
    /// bands are calibrated for a real embedding model's expected
    /// separation (near-duplicate labels cluster high, unrelated labels
    /// cluster low) rather than derived from this repo's own fake — see
    /// docs/specs/matching-confidence.md for the open item to retune
    /// against a real accuracy bench once one exists.
    private static let embeddingHighThreshold = 0.85
    private static let embeddingMediumThreshold = 0.5

    static func calibrate(score: Double, source: MatchSource) -> MatchConfidence {
        switch source {
        case .dictionary:
            // Exact normalized-string match — always high, no threshold.
            return .high
        case .embedding:
            if score >= embeddingHighThreshold { return .high }
            if score >= embeddingMediumThreshold { return .medium }
            return .low
        case .llm:
            // Only ever constructed for a validated constrained-choice
            // pick (SemanticMatcher never builds an .llm MatchCandidate
            // from a free-form/unvalidated response) — the LLM saw full
            // page-text context to disambiguate, stronger evidence than
            // the raw embedding score alone.
            return .high
        }
    }
}
