import Foundation

/// Closed-set document classification (e.g. "passport" vs "resume" vs
/// "W-9") — `candidateLabels` keeps this a constrained choice
/// (CLAUDE.md §19), never a free-form model guess.
public struct ClassifyRequest: Codable, Sendable, Equatable {
    public let imageData: Data
    public let candidateLabels: [String]
    public let priority: InferencePriority

    public init(imageData: Data, candidateLabels: [String], priority: InferencePriority = .interactive) {
        self.imageData = imageData
        self.candidateLabels = candidateLabels
        self.priority = priority
    }
}

public struct ClassifyResponse: Codable, Sendable, Equatable {
    public let label: String
    public let confidence: Double

    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
}
