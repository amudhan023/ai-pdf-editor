import Foundation

/// Label/text embeddings for semantic alias matching (ARCHITECTURE.md §7.1's
/// "always-available matcher" — bundled MiniLM-class model).
public struct EmbedRequest: Codable, Sendable, Equatable {
    public let texts: [String]
    public let priority: InferencePriority

    public init(texts: [String], priority: InferencePriority = .interactive) {
        self.texts = texts
        self.priority = priority
    }
}

/// One vector per input text, same order as `EmbedRequest.texts`.
public struct EmbedResponse: Codable, Sendable, Equatable {
    public let vectors: [[Float]]

    public init(vectors: [[Float]]) {
        self.vectors = vectors
    }
}
