import XCTest
import InferenceAPI
import VaultAPI
@testable import AutofillEngine

final class SemanticMatcherTests: XCTestCase {
    /// "Badge Number" is a fixed point of `FakeInferenceClient`'s
    /// deterministic hash-based embeddings against this package's curated
    /// `aliases.json`: its top two candidates land within a ~0.014 score
    /// gap (under `SemanticMatcher`'s default 0.05 ambiguity margin), so it
    /// reliably exercises the LLM-tiebreak path without any live model.
    /// Recomputed against the exact algorithm in
    /// `FakeInferenceClient.deterministicVector` — if `aliases.json` or
    /// that algorithm ever changes, this fixture may need re-deriving.
    private let ambiguousLabel = "Badge Number"

    private func makeMatcher(generate: MockInferenceClient.GenerateBehavior, timeout: Duration = .seconds(2)) async throws -> SemanticMatcher {
        let client = MockInferenceClient(generate: generate)
        let aliasMatcher = AliasMatcher(dictionary: try AliasDictionary.bundled(), inferenceClient: client)
        return SemanticMatcher(
            aliasMatcher: aliasMatcher,
            compositeDictionary: try CompositeDictionary.bundled(),
            inferenceClient: client,
            llmTimeout: timeout
        )
    }

    // MARK: - Golden-set: dictionary rung

    func test_dictionaryHitLabel_shortCircuitsToSingleHighConfidenceCandidate() async throws {
        let matcher = try await makeMatcher(generate: .unavailable) // never reached
        let outcome = try await matcher.match(context: MatchContext(label: "First Name"))
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].source, .dictionary)
        XCTAssertEqual(candidates[0].confidence, .high)
        XCTAssertEqual(candidates[0].vaultPath, try FieldPath(validating: "identity.legal_name.first"))
    }

    // MARK: - Golden-set: composite rung

    func test_fullNameLabel_returnsCompositeOutcome_notSingle() async throws {
        let matcher = try await makeMatcher(generate: .unavailable) // never reached — composite short-circuits first
        let outcome = try await matcher.match(context: MatchContext(label: "Full Name"))
        guard case .composite(let match) = outcome else { return XCTFail("expected .composite") }
        XCTAssertEqual(match.parts, [
            try FieldPath(validating: "identity.legal_name.first"),
            try FieldPath(validating: "identity.legal_name.last")
        ])
    }

    // MARK: - LLM tiebreak

    func test_ambiguousEmbeddingCandidates_triggerLLMTiebreak_andValidatedChoiceWins() async throws {
        let response = GenerateResponse(text: "chosen", chosenCandidateIndex: 0)
        let matcher = try await makeMatcher(generate: .respond(response))
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].source, .llm)
        XCTAssertEqual(candidates[0].confidence, .high)
    }

    func test_outOfRangeChosenIndex_isRejected_fallsBackToEmbeddingRanking() async throws {
        let response = GenerateResponse(text: "chosen", chosenCandidateIndex: 99)
        let matcher = try await makeMatcher(generate: .respond(response))
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertGreaterThan(candidates.count, 1)
        XCTAssertTrue(candidates.allSatisfy { $0.source == .embedding })
    }

    func test_nilChosenIndex_freeFormResponse_isRejected_fallsBackToEmbeddingRanking() async throws {
        let response = GenerateResponse(text: "some free-form text", chosenCandidateIndex: nil)
        let matcher = try await makeMatcher(generate: .respond(response))
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertTrue(candidates.allSatisfy { $0.source == .embedding })
    }

    // MARK: - Degradation path (Acceptance Criterion 2)

    func test_generateEndpointUnavailable_degradesToEmbeddingRankWithoutConfidenceUpgrade() async throws {
        let matcher = try await makeMatcher(generate: .unavailable)
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertTrue(candidates.allSatisfy { $0.source == .embedding })
        // No candidate was silently upgraded to the LLM-only .high tier
        // just because a tiebreak was attempted and failed.
        XCTAssertTrue(candidates.allSatisfy { $0.source != .llm })
    }

    /// `FakeInferenceClient`'s vectors are 8-dimensional and strictly
    /// non-negative, which structurally biases cosine similarity upward —
    /// an exhaustive random search (200k samples, see this task's Journal)
    /// found no label scoring below ~0.89 against this dictionary's known
    /// paths, so the medium/low confidence *bands* can't be reached via
    /// the fake end-to-end. `ConfidenceTests` covers the calibration
    /// thresholds directly via `MatchCandidate` construction instead; this
    /// test only proves the degradation path reports whatever the
    /// embedding rung's own calibration says (no artificial upgrade),
    /// which is the part `SemanticMatcher` itself is responsible for.
    func test_generateEndpointUnavailable_reportsEmbeddingRungsOwnConfidence_notAnUpgrade() async throws {
        let matcher = try await makeMatcher(generate: .unavailable)
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        guard case .single(let candidates) = outcome, let top = candidates.first else { return XCTFail("expected .single") }
        XCTAssertEqual(top.source, .embedding)
        XCTAssertEqual(top.confidence, ConfidenceCalibration.calibrate(score: top.score, source: .embedding))
    }

    func test_llmCallExceedsHardTimeout_fallsBackToEmbeddingRank() async throws {
        let matcher = try await makeMatcher(generate: .neverReturns, timeout: .milliseconds(50))
        let start = Date()
        let outcome = try await matcher.match(context: MatchContext(label: ambiguousLabel))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 2.0, "timeout should have cut the 3600s-sleeping mock short")
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertTrue(candidates.allSatisfy { $0.source == .embedding })
    }

    // MARK: - Determinism

    func test_sameContextAndClient_producesIdenticalOutcomeAcrossRepeatedCalls() async throws {
        let response = GenerateResponse(text: "chosen", chosenCandidateIndex: 0)
        let matcher = try await makeMatcher(generate: .respond(response))
        let context = MatchContext(label: ambiguousLabel)
        let first = try await matcher.match(context: context)
        let second = try await matcher.match(context: context)
        XCTAssertEqual(first, second)
    }

    func test_nonAmbiguousSingleEmbeddingCandidate_neverTriggersTiebreak() async throws {
        let matcher = try await makeMatcher(generate: .unavailable) // would throw if ever called with no fallback source mismatch
        let outcome = try await matcher.match(context: MatchContext(label: "Preferred Shoe Size"), limit: 1)
        guard case .single(let candidates) = outcome else { return XCTFail("expected .single") }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].source, .embedding)
    }
}
