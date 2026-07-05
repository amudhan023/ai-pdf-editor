import XCTest
import InferenceAPI
@testable import InferenceHost

final class EmbedTests: XCTestCase {
    func test_embed_isDeterministic_forRepeatedInput() async throws {
        let client = try await TestSupport.makeRealClient()
        let first = try await client.embed(EmbedRequest(texts: ["First Name"]))
        let second = try await client.embed(EmbedRequest(texts: ["First Name"]))
        XCTAssertEqual(first.vectors, second.vectors)
    }

    func test_embed_ranksSimilarLabelsCloserThanUnrelatedOnes() async throws {
        let client = try await TestSupport.makeRealClient()
        let response = try await client.embed(EmbedRequest(texts: [
            "first name", "given name", "annual income"
        ]))
        let (query, sameMeaning, unrelated) = (response.vectors[0], response.vectors[1], response.vectors[2])
        let closeScore = CosineSearch.similarity(query, sameMeaning)
        let farScore = CosineSearch.similarity(query, unrelated)
        XCTAssertGreaterThan(closeScore, farScore)
    }

    func test_embed_emptyTexts_returnsEmptyVectors() async throws {
        let client = try await TestSupport.makeRealClient()
        let response = try await client.embed(EmbedRequest(texts: []))
        XCTAssertTrue(response.vectors.isEmpty)
    }
}

final class CosineSearchTests: XCTestCase {
    func test_rank_ordersHighestSimilarityFirst() {
        let ranked = CosineSearch.rank(
            query: [1, 0],
            candidates: [
                (id: "orthogonal", vector: [0, 1]),
                (id: "identical", vector: [1, 0]),
                (id: "opposite", vector: [-1, 0])
            ]
        )
        XCTAssertEqual(ranked.map(\.id), ["identical", "orthogonal", "opposite"])
    }

    func test_similarity_zeroMagnitudeVector_returnsZeroNotNaN() {
        let score = CosineSearch.similarity([0, 0], [1, 1])
        XCTAssertEqual(score, 0)
        XCTAssertFalse(score.isNaN)
    }
}
