import XCTest
import InferenceAPI
import VaultAPI
@testable import AutofillEngine

final class AliasMatcherTests: XCTestCase {
    func test_dictionaryHit_returnsSingleCandidateWithDictionarySource() async throws {
        let matcher = AliasMatcher(dictionary: try AliasDictionary.bundled(), inferenceClient: FakeInferenceClient())
        let candidates = try await matcher.match(label: "First Name")
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.source, .dictionary)
        XCTAssertEqual(candidates.first?.score, 1.0)
        XCTAssertEqual(candidates.first?.vaultPath, try FieldPath(validating: "identity.legal_name.first"))
    }

    func test_dictionaryMiss_fallsThroughToEmbeddingRungWithAttribution() async throws {
        let matcher = AliasMatcher(dictionary: try AliasDictionary.bundled(), inferenceClient: FakeInferenceClient())
        let candidates = try await matcher.match(label: "Preferred Shoe Size")
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { $0.source == .embedding })
    }

    func test_embeddingCandidates_areRankedDescendingByScore() async throws {
        let matcher = AliasMatcher(dictionary: try AliasDictionary.bundled(), inferenceClient: FakeInferenceClient())
        let candidates = try await matcher.match(label: "Preferred Shoe Size", limit: 5)
        let scores = candidates.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func test_respectsLimitOnEmbeddingRung() async throws {
        let matcher = AliasMatcher(dictionary: try AliasDictionary.bundled(), inferenceClient: FakeInferenceClient())
        let candidates = try await matcher.match(label: "Preferred Shoe Size", limit: 3)
        XCTAssertLessThanOrEqual(candidates.count, 3)
    }
}
