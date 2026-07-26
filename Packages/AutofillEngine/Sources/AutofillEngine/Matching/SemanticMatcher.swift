import Foundation
import InferenceAPI
import VaultAPI

/// A matching-ladder result is either a single ranked candidate list, or a
/// composite decomposition plan (P2-03 Requirement 2) — never both, since a
/// composite label doesn't have "one score" to rank.
public enum MatchOutcome: Sendable, Equatable {
    case single([MatchCandidate])
    case composite(CompositeMatch)
}

/// Full matching ladder (P2-03): composite check -> `AliasMatcher`'s
/// dictionary/embedding rungs -> LLM tiebreak on ambiguous embedding
/// results. Composes the existing P1-14 `AliasMatcher` rather than
/// reimplementing dictionary/embedding matching.
public actor SemanticMatcher {
    private let aliasMatcher: AliasMatcher
    private let compositeDictionary: CompositeDictionary
    private let inferenceClient: InferenceClient
    private let llmTimeout: Duration
    private let ambiguityMargin: Double
    private let llmCandidateLimit: Int

    public init(
        aliasMatcher: AliasMatcher,
        compositeDictionary: CompositeDictionary,
        inferenceClient: InferenceClient,
        llmTimeout: Duration = .seconds(2),
        ambiguityMargin: Double = 0.05,
        llmCandidateLimit: Int = 3
    ) {
        self.aliasMatcher = aliasMatcher
        self.compositeDictionary = compositeDictionary
        self.inferenceClient = inferenceClient
        self.llmTimeout = llmTimeout
        self.ambiguityMargin = ambiguityMargin
        self.llmCandidateLimit = llmCandidateLimit
    }

    /// Deterministic given the same `context` and a deterministic
    /// `InferenceClient` (temperature/seed control is delegated to the
    /// concrete adapter behind `InferenceClient` — this package only sets
    /// `GenerateRequest.priority`, the one determinism-adjacent knob
    /// `InferenceAPI` currently exposes; see
    /// docs/specs/matching-confidence.md for the open item this leaves).
    public func match(context: MatchContext, limit: Int = 5) async throws -> MatchOutcome {
        let normalizedLabel = LabelNormalizer.normalize(context.label)
        if let composite = compositeDictionary.lookup(normalizedLabel: normalizedLabel) {
            return .composite(composite)
        }

        let candidates = try await aliasMatcher.match(
            label: context.label,
            queryText: context.assembledText,
            limit: limit
        )

        guard isAmbiguous(candidates) else {
            return .single(candidates)
        }

        guard let resolved = await tiebreak(context: context, candidates: candidates) else {
            // Timeout, throw, invalid response, or a non-in-range choice —
            // graceful fallback to the untouched embedding ranking
            // (Requirement 3 / Acceptance Criterion 2: confidence stays at
            // the embedding rung's own calibrated tier, never upgraded).
            return .single(candidates)
        }
        return .single([resolved])
    }

    /// Ambiguous only when the top two *embedding* candidates are within
    /// `ambiguityMargin` of each other — a dictionary hit is always a
    /// single exact-match candidate (never reaches here), and a single
    /// embedding candidate has nothing to tie-break against.
    private func isAmbiguous(_ candidates: [MatchCandidate]) -> Bool {
        guard candidates.count >= 2, candidates[0].source == .embedding else { return false }
        return (candidates[0].score - candidates[1].score) <= ambiguityMargin
    }

    private func tiebreak(context: MatchContext, candidates: [MatchCandidate]) async -> MatchCandidate? {
        let shortlist = Array(candidates.prefix(llmCandidateLimit))
        let paths = shortlist.map(\.vaultPath.description)
        let prompt = """
        Field context: \(context.assembledText)
        Choose the vault field path that best matches this form field from the candidates.
        """
        let request = GenerateRequest(prompt: prompt, candidates: paths, priority: .interactive)

        guard let response = await generateWithTimeout(request) else { return nil }
        guard let index = response.chosenCandidateIndex, shortlist.indices.contains(index) else {
            // A `nil` index (free-form fallback) or an out-of-range index
            // is structurally untrustworthy per CLAUDE.md §19 — never
            // treated as a path, always falls back.
            return nil
        }
        let chosen = shortlist[index]
        return MatchCandidate(vaultPath: chosen.vaultPath, score: chosen.score, source: .llm)
    }

    /// Hard timeout (Requirement 3): races the real call against a sleep,
    /// cancels the loser. Any thrown error (including a simulated
    /// `capabilityUnavailable` on an Intel-tier machine with no LLM tier)
    /// degrades to `nil`, same as a timeout — both are "the LLM rung isn't
    /// usable right now," handled identically by the caller.
    private func generateWithTimeout(_ request: GenerateRequest) async -> GenerateResponse? {
        await withTaskGroup(of: GenerateResponse?.self) { group in
            group.addTask { try? await self.inferenceClient.generate(request) }
            group.addTask {
                try? await Task.sleep(for: self.llmTimeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
