import Foundation
import InferenceAPI
import VaultAPI

/// Which matching-ladder rung produced a candidate (ARCHITECTURE.md §7.1).
/// The review UI depends on this attribution being present on every
/// candidate (CLAUDE.md §19).
public enum MatchSource: String, Sendable, Equatable {
    case dictionary
    case embedding
    case llm
}

public struct MatchCandidate: Sendable, Equatable {
    public let vaultPath: FieldPath
    public let score: Double
    public let source: MatchSource
    /// Calibrated high/medium/low tier, derived from `score`/`source` — see
    /// `ConfidenceCalibration` and docs/specs/matching-confidence.md.
    public let confidence: MatchConfidence

    public init(vaultPath: FieldPath, score: Double, source: MatchSource) {
        self.vaultPath = vaultPath
        self.score = score
        self.source = source
        self.confidence = ConfidenceCalibration.calibrate(score: score, source: source)
    }
}

/// Label + context -> ranked candidates. Dictionary rung first (exact,
/// normalized, deterministic); embedding rung only runs on a dictionary
/// miss (Requirements: "dictionary miss falls through to embedding rung
/// with correct score attribution").
public actor AliasMatcher {
    private let dictionary: AliasDictionary
    private let inferenceClient: InferenceClient
    private var cachedAliasEmbeddings: [(path: FieldPath, vector: [Float])]?

    public init(dictionary: AliasDictionary, inferenceClient: InferenceClient) {
        self.dictionary = dictionary
        self.inferenceClient = inferenceClient
    }

    /// Returns the single dictionary hit if the normalized `label` matches
    /// exactly; otherwise up to `limit` embedding candidates ranked by
    /// cosine similarity to the dictionary's own canonical path strings
    /// (the only vault-path aliases this rung has anything to compare
    /// against without a live `VaultClient` lookup).
    ///
    /// `queryText` (P2-03) lets a caller enrich *only* the embedding
    /// rung's query with page-text context (tooltip/nearby text/section
    /// headers assembled by `ContextAssembler`) without disturbing the
    /// dictionary rung's exact-match precision — dictionary lookup always
    /// uses `label` alone, since a context-diluted string would
    /// legitimately miss a curated alias that the bare label would hit
    /// (that'd be a regression against the P1-14 baseline, not an
    /// improvement). Defaults to `label` itself, so existing callers are
    /// unaffected.
    public func match(label: String, queryText: String? = nil, limit: Int = 5) async throws -> [MatchCandidate] {
        let normalized = LabelNormalizer.normalize(label)
        if let path = dictionary.lookup(normalizedLabel: normalized) {
            return [MatchCandidate(vaultPath: path, score: 1.0, source: .dictionary)]
        }

        let normalizedQuery = LabelNormalizer.normalize(queryText ?? label)
        let aliasEmbeddings = try await loadAliasEmbeddingsIfNeeded()
        guard let queryVector = try await inferenceClient.embed(EmbedRequest(texts: [normalizedQuery])).vectors.first else {
            return []
        }
        return aliasEmbeddings
            .map { (path: $0.path, score: cosineSimilarity(queryVector, $0.vector)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { MatchCandidate(vaultPath: $0.path, score: $0.score, source: .embedding) }
    }

    /// Batch-embeds each known vault path's dot-separated string once, then
    /// caches the result for the lifetime of this actor — avoids re-running
    /// inference for the same fixed candidate set on every miss.
    private func loadAliasEmbeddingsIfNeeded() async throws -> [(path: FieldPath, vector: [Float])] {
        if let cached = cachedAliasEmbeddings { return cached }
        let paths = dictionary.knownPaths
        let vectors = try await inferenceClient.embed(
            EmbedRequest(texts: paths.map { $0.description.replacingOccurrences(of: ".", with: " ") })
        ).vectors
        let paired = zip(paths, vectors).map { (path: $0, vector: $1) }
        cachedAliasEmbeddings = paired
        return paired
    }

    /// Duplicates `InferenceHost.CosineSearch.similarity` rather than
    /// importing it: `AutofillEngine`'s import allowlist only permits
    /// `InferenceAPI` (the frozen contract), not the XPC-adjacent
    /// `InferenceHost` implementation package (Scripts/import-allowlist.txt).
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Double = 0, magA: Double = 0, magB: Double = 0
        for index in 0..<a.count {
            let x = Double(a[index]), y = Double(b[index])
            dot += x * y
            magA += x * x
            magB += y * y
        }
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA.squareRoot() * magB.squareRoot())
    }
}
