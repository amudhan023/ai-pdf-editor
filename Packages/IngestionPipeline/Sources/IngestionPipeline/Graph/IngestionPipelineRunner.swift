import Foundation
import PDFEngineAPI

/// The stage graph runtime (Requirements: "typed stage protocol, cancellable,
/// progress reporting, per-stage error isolation"). Fixed sequence
/// normalize -> classify (both required — a failure there fails the whole
/// run, there's nothing downstream to isolate it from), then every
/// registered `ExtractorStage` that `supports` the classification runs
/// concurrently with its own failure isolated from its siblings (a bad
/// extractor never kills the pipeline or another extractor's output).
///
/// Cancellation: cooperative, via `Task.checkCancellation()` between/within
/// stages and `withThrowingTaskGroup`'s automatic propagation to child
/// extractor tasks — cancelling the calling `Task` cancels every extractor
/// still running.
public actor IngestionPipelineRunner {
    private let normalizer: Normalizer
    private let classifier: DocumentClassifier
    private let extractors: [any ExtractorStage]

    public init(normalizer: Normalizer, classifier: DocumentClassifier, extractors: [any ExtractorStage]) {
        self.normalizer = normalizer
        self.classifier = classifier
        self.extractors = extractors
    }

    public func run(
        fileURL: URL,
        document: DocumentHandle? = nil,
        onProgress: (@Sendable (IngestionProgressEvent) -> Void)? = nil
    ) async throws -> IngestionResult {
        onProgress?(.stageStarted("normalize"))
        let normalized: NormalizedDocument
        do {
            normalized = try await normalizer.normalize(fileURL: fileURL, document: document)
        } catch is CancellationError {
            onProgress?(.stageFailed("normalize", debugDescription: IngestionError.cancelled.debugDescription))
            throw IngestionError.cancelled
        } catch let error as IngestionError {
            onProgress?(.stageFailed("normalize", debugDescription: error.debugDescription))
            throw error
        }
        onProgress?(.stageCompleted("normalize"))

        try Task.checkCancellation()

        onProgress?(.stageStarted("classify"))
        // Classify off the first page carrying image data — a document's
        // "type" is a whole-document property, not per-page; using the
        // first classifiable page keeps this a single endpoint call rather
        // than one per page.
        let classification: DocumentClassification
        if let firstImagePage = normalized.pages.first(where: { $0.imageData != nil }) {
            classification = await classifier.classify(firstImagePage)
        } else {
            classification = DocumentClassification(type: .generic, confidence: 0, isFallback: true)
        }
        onProgress?(.stageCompleted("classify"))

        try Task.checkCancellation()

        let applicable = extractors.filter { $0.supports(classification) }
        guard !applicable.isEmpty else {
            return IngestionResult(classification: classification, candidates: [])
        }

        var candidates: [ExtractionCandidate] = []
        var failures: [String: IngestionError] = [:]

        await withTaskGroup(of: (String, Result<[ExtractionCandidate], Error>).self) { group in
            for extractor in applicable {
                let name = extractor.name
                onProgress?(.stageStarted(name))
                group.addTask {
                    do {
                        let result = try await extractor.extract(from: normalized, classification: classification)
                        return (name, .success(result))
                    } catch {
                        return (name, .failure(error))
                    }
                }
            }
            for await (name, outcome) in group {
                switch outcome {
                case .success(let extracted):
                    candidates.append(contentsOf: extracted)
                    onProgress?(.stageCompleted(name))
                case .failure(let error):
                    let typed = (error as? IngestionError) ?? .engine(String(describing: type(of: error)))
                    failures[name] = typed
                    onProgress?(.stageFailed(name, debugDescription: typed.debugDescription))
                }
            }
        }

        return IngestionResult(classification: classification, candidates: candidates, failedExtractors: failures)
    }
}
