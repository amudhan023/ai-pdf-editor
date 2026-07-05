import Foundation

/// A conformance check failed. Carries a human-readable reason; test
/// targets turn these into failures with useful output. Identical shape to
/// `VaultAPI.ConformanceFailure`/`PDFEngineAPI.ConformanceFailure`.
public struct ConformanceFailure: Error, CustomStringConvertible {
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
    public var description: String { reason }
}

/// Protocol-conformance checks any real `InferenceClient` implementation
/// must also pass — shipped here (not `Tests/`) so `InferenceHost`'s test
/// target can run the identical suite against its real
/// registry/router-backed client, alongside `FakeInferenceClient` (this
/// task's stated acceptance criterion). These check the *structural*
/// contract every implementation must honor (response shape, constrained
/// choice), not model accuracy — accuracy is the bench suite's job
/// (CLAUDE.md §9) once real adapters land (P1-13+).
public enum InferenceConformanceSuite {
    public static func verifyOCRReturnsRegions<C: InferenceClient>(_ client: C) async throws {
        let response = try await client.ocr(OCRRequest(imageData: Data([0x01, 0x02, 0x03])))
        guard !response.regions.isEmpty else {
            throw ConformanceFailure("ocr must return at least one region for non-empty imageData")
        }
        for region in response.regions {
            guard (0...1).contains(region.confidence) else {
                throw ConformanceFailure("ocr region confidence must be in 0...1, got \(region.confidence)")
            }
        }
    }

    public static func verifyClassifyPicksFromCandidateLabels<C: InferenceClient>(_ client: C) async throws {
        let labels = ["passport", "resume", "w9"]
        let response = try await client.classify(
            ClassifyRequest(imageData: Data([0x01]), candidateLabels: labels)
        )
        guard labels.contains(response.label) else {
            throw ConformanceFailure("classify must return one of the candidateLabels, got \(response.label)")
        }
        guard (0...1).contains(response.confidence) else {
            throw ConformanceFailure("classify confidence must be in 0...1, got \(response.confidence)")
        }
    }

    public static func verifyClassifyRejectsEmptyCandidates<C: InferenceClient>(_ client: C) async throws {
        var threw = false
        do {
            _ = try await client.classify(ClassifyRequest(imageData: Data([0x01]), candidateLabels: []))
        } catch {
            threw = true
        }
        guard threw else { throw ConformanceFailure("classify must throw when candidateLabels is empty") }
    }

    public static func verifyExtractEntitiesRespectsSchema<C: InferenceClient>(_ client: C) async throws {
        let schema = ["identity.date_of_birth", "identity.passport.number"]
        let response = try await client.extractEntities(
            ExtractEntitiesRequest(text: "irrelevant for the structural contract", schema: schema)
        )
        for entity in response.entities {
            guard schema.contains(entity.type) else {
                throw ConformanceFailure("extractEntities must only return types from the requested schema, got \(entity.type)")
            }
        }
    }

    public static func verifyEmbedReturnsVectorPerText<C: InferenceClient>(_ client: C) async throws {
        let texts = ["Full Legal Name", "Date of Birth", "Passport Number"]
        let response = try await client.embed(EmbedRequest(texts: texts))
        guard response.vectors.count == texts.count else {
            throw ConformanceFailure("embed must return one vector per input text")
        }
        guard response.vectors.allSatisfy({ !$0.isEmpty }) else {
            throw ConformanceFailure("embed must not return an empty vector")
        }
    }

    public static func verifyGenerateConstrainedChoice<C: InferenceClient>(_ client: C) async throws {
        let candidates = ["MM/DD/YYYY", "DD/MM/YYYY", "YYYY-MM-DD"]
        let response = try await client.generate(GenerateRequest(prompt: "pick a date format", candidates: candidates))
        guard let index = response.chosenCandidateIndex else {
            throw ConformanceFailure("generate must set chosenCandidateIndex when candidates is non-empty")
        }
        guard candidates.indices.contains(index), candidates[index] == response.text else {
            throw ConformanceFailure("generate's chosenCandidateIndex must index into candidates and match text")
        }
    }

    public static func runAll<C: InferenceClient>(_ client: C) async throws {
        try await verifyOCRReturnsRegions(client)
        try await verifyClassifyPicksFromCandidateLabels(client)
        try await verifyClassifyRejectsEmptyCandidates(client)
        try await verifyExtractEntitiesRespectsSchema(client)
        try await verifyEmbedReturnsVectorPerText(client)
        try await verifyGenerateConstrainedChoice(client)
    }
}
