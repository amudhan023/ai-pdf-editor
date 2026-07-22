import Foundation
import PDFEngineAPI
import VaultAPI

/// Where in the source document a candidate value was found — reuses
/// `PDFEngineAPI`'s existing page/geometry types rather than inventing new
/// ones (CLAUDE.md §18 "don't reinvent"). `page`/`rect` are `nil` for
/// non-paginated sources (e.g. a DOCX/TXT normalizer, once one exists).
public struct SourceRegion: Sendable, Equatable {
    public let page: PageIndex?
    public let rect: PDFRect?

    public init(page: PageIndex? = nil, rect: PDFRect? = nil) {
        self.page = page
        self.rect = rect
    }
}

/// Which pipeline stage/extractor produced a candidate — the review UI's
/// provenance contract (CLAUDE.md §19), mirroring `AutofillEngine.MatchSource`'s
/// attribution role for the matching ladder.
public struct ExtractorAttribution: Sendable, Equatable {
    public let extractorName: String

    public init(extractorName: String) {
        self.extractorName = extractorName
    }
}

/// One proposed vault write, emitted by an extractor stage. The pipeline
/// (this package) never writes to the vault itself — persistence happens in
/// the review session (P2-11); this type is the wire format between them.
public struct ExtractionCandidate: Sendable, Equatable {
    public let value: String
    public let proposedPath: FieldPath
    public let sourceRegion: SourceRegion
    public let confidence: Double
    public let attribution: ExtractorAttribution

    public init(
        value: String,
        proposedPath: FieldPath,
        sourceRegion: SourceRegion,
        confidence: Double,
        attribution: ExtractorAttribution
    ) {
        self.value = value
        self.proposedPath = proposedPath
        self.sourceRegion = sourceRegion
        self.confidence = confidence
        self.attribution = attribution
    }
}
