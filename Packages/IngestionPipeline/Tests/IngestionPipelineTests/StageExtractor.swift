import Foundation
import VaultAPI
@testable import IngestionPipeline

/// Test-local `ExtractorStage`s exercising the runner's contract: a
/// scripted extractor that always succeeds, one that always throws, and
/// one that spins until cancelled — none of this belongs in a real
/// extractor (P2-09/P2-10 own those), it's purely for testing
/// `IngestionPipelineRunner`'s isolation/cancellation guarantees.
struct ScriptedExtractor: ExtractorStage {
    let name: String
    let supportedTypes: Set<DocumentType>
    let behavior: Behavior

    enum Behavior {
        case succeed([ExtractionCandidate])
        case fail(IngestionError)
    }

    func supports(_ classification: DocumentClassification) -> Bool {
        supportedTypes.contains(classification.type)
    }

    func extract(from document: NormalizedDocument, classification: DocumentClassification) async throws -> [ExtractionCandidate] {
        switch behavior {
        case .succeed(let candidates): return candidates
        case .fail(let error): throw error
        }
    }
}

struct CancellationProbeExtractor: ExtractorStage {
    let name = "cancellation-probe"

    func supports(_ classification: DocumentClassification) -> Bool { true }

    func extract(from document: NormalizedDocument, classification: DocumentClassification) async throws -> [ExtractionCandidate] {
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw CancellationError()
    }
}

func makeCandidate(value: String = "Jane Doe") throws -> ExtractionCandidate {
    ExtractionCandidate(
        value: value,
        proposedPath: try FieldPath(validating: "identity.legal_name"),
        sourceRegion: SourceRegion(),
        confidence: 0.9,
        attribution: ExtractorAttribution(extractorName: "test")
    )
}
