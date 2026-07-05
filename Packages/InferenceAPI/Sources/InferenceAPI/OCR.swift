import Foundation

public struct OCRRequest: Codable, Sendable, Equatable {
    public let imageData: Data
    public let priority: InferencePriority

    public init(imageData: Data, priority: InferencePriority = .interactive) {
        self.imageData = imageData
        self.priority = priority
    }
}

public struct OCRTextRegion: Codable, Sendable, Equatable {
    public let text: String
    public let boundingBox: NormalizedRect
    public let confidence: Double

    public init(text: String, boundingBox: NormalizedRect, confidence: Double) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public struct OCRResponse: Codable, Sendable, Equatable {
    public let regions: [OCRTextRegion]

    public init(regions: [OCRTextRegion]) {
        self.regions = regions
    }
}
