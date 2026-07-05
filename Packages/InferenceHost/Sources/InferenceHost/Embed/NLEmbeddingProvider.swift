import Foundation
import NaturalLanguage
import InferenceAPI

/// Real embed-rung backend: Apple's on-device `NLEmbedding` (NaturalLanguage
/// framework) sentence embeddings. Ships with macOS — no model pack to
/// fetch, sign, or vendor, which sidesteps `ModelRegistry`'s packData path
/// entirely (same as the stub it replaces, `embed(_:manifest:)` never reads
/// `manifest.packData`). This is a deliberate substitution for the task's
/// original "bundled Core ML model" framing: no third-party ML binary can
/// be vendored into this repo without a human trust decision (see
/// `tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`'s
/// "Key lesson" for the harness-level control that applies), and a
/// system-provided embedding is a strictly stronger fit for "zero network
/// dependency" than a fetched one would be.
public actor NLEmbeddingProvider {
    private var embeddingsByLanguage: [NLLanguage: NLEmbedding] = [:]

    public init() {}

    /// One vector per input text, same order as `texts`. Throws
    /// `.capabilityUnavailable` (never crashes) if no sentence embedding is
    /// installed for the detected/requested language — a normal, typed
    /// degradation per CLAUDE.md §15, not an error condition to swallow.
    public func embed(_ texts: [String], language: NLLanguage = .english) throws -> [[Float]] {
        let embedding = try embedding(for: language)
        return try texts.map { text in
            guard let vector = embedding.vector(for: text) else {
                throw InferenceError.adapterFailure(reason: "no embedding vector for input text")
            }
            return vector.map(Float.init)
        }
    }

    private func embedding(for language: NLLanguage) throws -> NLEmbedding {
        if let cached = embeddingsByLanguage[language] {
            return cached
        }
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            throw InferenceError.capabilityUnavailable(.embed, HardwareTierDetector.current())
        }
        embeddingsByLanguage[language] = embedding
        return embedding
    }
}
