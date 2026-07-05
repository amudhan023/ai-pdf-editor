import Foundation

/// LLM path (match tiebreak, composite reasoning). `candidates` is the
/// constrained-choice list (CLAUDE.md §19: "LLM output is constrained
/// choice... wherever possible"); an empty list falls back to free-form
/// generation for the rare composite-reasoning case, which callers must
/// still validate deterministically before use — this endpoint makes no
/// hallucination guarantee on its own.
public struct GenerateRequest: Codable, Sendable, Equatable {
    public let prompt: String
    public let candidates: [String]
    public let priority: InferencePriority

    public init(prompt: String, candidates: [String] = [], priority: InferencePriority = .interactive) {
        self.prompt = prompt
        self.candidates = candidates
        self.priority = priority
    }
}

public struct GenerateResponse: Codable, Sendable, Equatable {
    public let text: String
    /// Index into the request's `candidates` when the constrained-choice
    /// path was used; `nil` for free-form generation.
    public let chosenCandidateIndex: Int?

    public init(text: String, chosenCandidateIndex: Int?) {
        self.text = text
        self.chosenCandidateIndex = chosenCandidateIndex
    }
}
