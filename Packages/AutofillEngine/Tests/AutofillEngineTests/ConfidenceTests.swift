import XCTest
import VaultAPI
@testable import AutofillEngine

final class ConfidenceTests: XCTestCase {
    func test_dictionarySource_isAlwaysHighRegardlessOfScore() throws {
        let path = try FieldPath(validating: "identity.legal_name.first")
        // Real dictionary hits are always score 1.0, but confidence must
        // not depend on an incidental score value for this source.
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.4, source: .dictionary).confidence, .high)
    }

    func test_embeddingSource_highBand() throws {
        let path = try FieldPath(validating: "identity.legal_name.first")
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.9, source: .embedding).confidence, .high)
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.85, source: .embedding).confidence, .high)
    }

    func test_embeddingSource_mediumBand() throws {
        let path = try FieldPath(validating: "identity.legal_name.first")
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.7, source: .embedding).confidence, .medium)
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.5, source: .embedding).confidence, .medium)
    }

    func test_embeddingSource_lowBand() throws {
        let path = try FieldPath(validating: "identity.legal_name.first")
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.49, source: .embedding).confidence, .low)
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.0, source: .embedding).confidence, .low)
    }

    func test_llmSource_isAlwaysHigh() throws {
        let path = try FieldPath(validating: "identity.legal_name.first")
        XCTAssertEqual(MatchCandidate(vaultPath: path, score: 0.6, source: .llm).confidence, .high)
    }
}
