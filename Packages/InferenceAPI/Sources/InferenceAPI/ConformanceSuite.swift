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
    /// A small real PNG (200x60, white background, black "HELLO" text,
    /// generated once via CoreGraphics/ImageIO) — see ADR-012. A real OCR
    /// engine can honestly recognize text in this image; the earlier
    /// fixture (three arbitrary bytes) could only be "passed" by a stub
    /// that fabricated output for undecodable input.
    private static let ocrFixturePNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAMgAAAA8CAYAAAAjW/WRAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAA" +
        "ABAAAAyKADAAQAAAABAAAAPAAAAAAFJ+kyAAAGqElEQVR4Ae2cXUgVTRjHH+2VNNEINO3DuilFScqMIBHxwrKbqKREr1RUCIIM8aYwgsSgvLLsTgiKLgIt" +
        "wqAPL1RIgrrJTxQszLS0zCghKSnb5/AeObszbrPHM3rO9h9Yzplnnnl25jfzP2c/ZjdswUiEBAIgICUQLrXCCAIg4CEAgWAigIANAQjEBg6KQAACwRwAAR" +
        "sCEIgNHBSBAASCOQACNgQgEBs4KAIBCARzAARsCEAgNnBQBAIQCOYACNgQgEBs4KAIBCAQzAEQsCEAgdjAQREI/OcUQWtrK33//t1Ubf/+/ZSSkmKyLZX5" +
        "9u0bPXjwQCg+evQoxcbGLtpl+1ksVPgSGRlJJ0+eNHnKYjppuymYkQl0PGt8b76np4fa29tpbGyM3r17R1NTUxQXF0dJSUm0bds2ysnJoQMHDnjd8RlIAr" +
        "zc3UnaunUrL483bTdu3FAOMTQ0ZKrrjTU8PGyKIduP11flc+PGjaZ4nJHFdNJ2a8BAx/ONPz8/v9Dc3LxgCFjKy8pg165dC9euXVswfrx8w+D7MgngEMuY" +
        "acGWPn78SHl5eVRRUUEvXrxQal5/fz+dOXOGsrKyaHR0VKkOnP5OAAL5O6MV9Xj16hVlZmZSV1eXX/v11u/s7PSrPiqZCUAgZh6rmpudnaXjx4/T+Pi4tB" +
        "1r166ltLQ0OnjwIKWnp9O6deukfjMzM3TixAn68OGDtBxGdQIhJZDr16/Tr1+/lLZQnBxVVVXSw6OYmBi6fPmy5+R8YGCAnj59Sr29vfTp0ydqbGyk+Ph4" +
        "YcQ/f/5M5eXlgh0GZwRCSiDh4eHkZHOGYnW9nz17Rjdv3hQawZO/o6ODzp07R+vXrzeV8z8In3d0d3fT9u3bTWWcefToEbW0tAh2GNQJhJRA1LsVep63bt" +
        "2SNvr27duecxJp4f/GnTt30r179zw/Hla/peJa/ZCXE4BA5FxW1Prz50/pL/2RI0coPz9fqS179+6lsrIywffJkyf05csXwQ6DGgEIRI2TVi++4iSbxCUl" +
        "JY72W1paKviz+Nra2gQ7DGoEHN9Jl4Wdm5sjvkOukvhKDZKZwOvXr80GIxcREUGHDh0S7HYGvpu+YcMGQWxv3ryxq4YyGwIBEUhNTQ3xpjudP3+e6uvrlX" +
        "Zz9+5dys7OVvJdbaf3798LTdi8eTPx1Ssnac2aNcTnI9abi6F4Rc9Jv3X6BkQgOhvoG/vr16/Em0r68eOHiltQ+MgmsLFUxq+2yerJBOhX8H+wEs5BgmDQ" +
        "ZYed0dHRfrVMVk8W36/g/2AlCCQIBl32q883+vxJ09PTQrWEhATBBoMagYAcYlVWVtLhw4eV9jgxMeG5uaXkbHHiO83Hjh2zWOXZPXv2yAuC0MrnG9bES9" +
        "r9SbzQ0Zo2bdpkNSGvSCAgAuHJWFBQoLRLY1m7kp/MKTk5mXJzc2VFIW2TTWCe6CMjI7Rjxw7lvvGl4sHBQcFfJkDBCQYpARxiSbGsrHHfvn3SHTq9f/H4" +
        "8WPPOjVrsKXiW/2QFwlAICKTFbcYDzsRb9bECxH5HpNK+v37N129elVwTUxMdOW/rtBRTQYIRBNYp2GLi4uFKm/fvqWLFy8KdpnBeJqQ+FkQayosLJSu0b" +
        "L6IS8nAIHIuay4lZeV+D6T721AQ0MD1dbWkvHkqNckfDY1NVF1dbVg5+dHTp06JdhhUCcQkJN09d0tz/P58+dLPiRkjcwvbSgqKrKahbyTmLt376aMjAwh" +
        "hq/B33hbtmwh/heQrafi1QP379+ns2fPEi9KZN/JyUnq6+sjfkbm5cuXvk1Y/F5XV0epqamLeXzxg4DTZ9qX+6KCYHtpg4GMf5qVtgsXLphwyVioxmI/az" +
        "wOblwNVGrL3/ZjvOlkwXi4zNReZJwTwCGWMdOCKd25c0f6L+KkjXyv6OHDhzj3cAJtCV8IZAkwq2XmQ0N+spDPK6Kiohw1g1cAX7p0yfPwlNOFjo529A85" +
        "QyBBOtinT58mXmTI5yWyS8C+zeabiVeuXPG87ME4bKOwsDDfYnxfBoEwPipbRn1UXSECvPSE36pofbMiv12R78RDFHoGAgLRwxVRXUIAh1guGUh0Qw8BCE" +
        "QPV0R1CQEIxCUDiW7oIQCB6OGKqC4hAIG4ZCDRDT0EIBA9XBHVJQQgEJcMJLqhhwAEoocrorqEAATikoFEN/QQgED0cEVUlxCAQFwykOiGHgIQiB6uiOoS" +
        "AhCISwYS3dBDAALRwxVRXUIAAnHJQKIbeghAIHq4IqpLCEAgLhlIdEMPAQhED1dEdQmBP8zXVkXl22RVAAAAAElFTkSuQmCC"

    public static func verifyOCRReturnsRegions<C: InferenceClient>(_ client: C) async throws {
        guard let imageData = Data(base64Encoded: ocrFixturePNGBase64) else {
            throw ConformanceFailure("ocrFixturePNGBase64 is not valid base64 — fixture corrupted")
        }
        let response = try await client.ocr(OCRRequest(imageData: imageData))
        guard !response.regions.isEmpty else {
            throw ConformanceFailure("ocr must return at least one region for a decodable image containing text")
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
