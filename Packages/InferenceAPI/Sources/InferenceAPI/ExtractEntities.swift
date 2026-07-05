import Foundation

/// Entity extraction over already-recognized text. `schema` is the closed
/// set of entity types the caller wants (e.g. `["identity.date_of_birth"]`)
/// — the response never includes types outside it, keeping this a
/// constrained-choice endpoint rather than an open-ended NER dump.
public struct ExtractEntitiesRequest: Codable, Sendable, Equatable {
    public let text: String
    public let schema: [String]
    public let priority: InferencePriority

    public init(text: String, schema: [String], priority: InferencePriority = .interactive) {
        self.text = text
        self.schema = schema
        self.priority = priority
    }
}

/// `startOffset`/`length` are UTF-8 byte offsets into the request's `text`
/// (not a `String.Index`/`Range`, which isn't `Codable` across an XPC
/// boundary) — callers reconstruct the substring with
/// `String.Index(utf8Offset:in:)`.
public struct ExtractedEntity: Codable, Sendable, Equatable {
    public let type: String
    public let value: String
    public let startOffset: Int
    public let length: Int
    public let confidence: Double

    public init(type: String, value: String, startOffset: Int, length: Int, confidence: Double) {
        self.type = type
        self.value = value
        self.startOffset = startOffset
        self.length = length
        self.confidence = confidence
    }
}

public struct ExtractEntitiesResponse: Codable, Sendable, Equatable {
    public let entities: [ExtractedEntity]

    public init(entities: [ExtractedEntity]) {
        self.entities = entities
    }
}
