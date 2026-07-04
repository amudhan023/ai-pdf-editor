import Foundation

/// A region on a document page, in the same normalized shape ingestion's
/// extractors report (page-relative fraction, not device pixels, so it
/// survives DPI/zoom differences). Foundation-only, so this is a local
/// stand-in rather than a `CGRect` — same reason as `PDFEngineAPI`'s
/// `PDFRect` (this package may not import CoreGraphics either).
public struct ProvenanceRegion: Sendable, Codable, Equatable {
    public let originX: Double
    public let originY: Double
    public let width: Double
    public let height: Double

    public init(originX: Double, originY: Double, width: Double, height: Double) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }
}

/// Where a field's value came from (task requirement: "manual |
/// document+page+region+confidence"). Every `ProfileField` carries one —
/// CLAUDE.md's product truth #3, "every value is traceable to its source."
public enum Provenance: Sendable, Equatable {
    case manual
    case document(documentID: UUID, page: Int, region: ProvenanceRegion?, confidence: Double)
}

extension Provenance: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case documentID
        case page
        case region
        case confidence
    }

    private enum Kind: String, Codable {
        case manual
        case document
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .manual:
            self = .manual
        case .document:
            self = .document(
                documentID: try container.decode(UUID.self, forKey: .documentID),
                page: try container.decode(Int.self, forKey: .page),
                region: try container.decodeIfPresent(ProvenanceRegion.self, forKey: .region),
                confidence: try container.decode(Double.self, forKey: .confidence)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try container.encode(Kind.manual, forKey: .kind)
        case .document(let documentID, let page, let region, let confidence):
            try container.encode(Kind.document, forKey: .kind)
            try container.encode(documentID, forKey: .documentID)
            try container.encode(page, forKey: .page)
            try container.encodeIfPresent(region, forKey: .region)
            try container.encode(confidence, forKey: .confidence)
        }
    }
}
