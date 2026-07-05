import XCTest
import VaultAPI
@testable import AutofillEngine

final class AliasDictionaryTests: XCTestCase {
    func test_bundledDictionaryLoads() throws {
        let dictionary = try AliasDictionary.bundled()
        XCTAssertFalse(dictionary.knownPaths.isEmpty)
    }

    func test_exactNormalizedLabelResolvesToCanonicalPath() throws {
        let dictionary = try AliasDictionary.bundled()
        let path = try FieldPath(validating: "identity.legal_name.first")
        XCTAssertEqual(dictionary.lookup(normalizedLabel: "first name"), path)
        XCTAssertEqual(dictionary.lookup(normalizedLabel: "given name"), path)
    }

    func test_localeVariantResolvesToSamePath() throws {
        let dictionary = try AliasDictionary.bundled()
        let path = try FieldPath(validating: "contact.email.primary")
        XCTAssertEqual(dictionary.lookup(normalizedLabel: LabelNormalizer.normalize("Correo Electrónico".lowercased())), path)
    }

    func test_unknownLabelMisses() throws {
        let dictionary = try AliasDictionary.bundled()
        XCTAssertNil(dictionary.lookup(normalizedLabel: "favorite dinosaur"))
    }

    /// NFR-A1 precision bench: every curated label variant must resolve to
    /// its own entry's vault path once normalized — this is what "≥95%
    /// precision on the top-N label fixture set" means for a rung that's
    /// exact-match by construction (a failure here means normalization
    /// collapsed two different labels onto the same string, a real
    /// dictionary defect, not sampling noise).
    func test_precisionBench_everyCuratedVariantResolvesCorrectly() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "aliases", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        let dictionary = try AliasDictionary.bundled()

        var attempted = 0
        var correct = 0
        for entry in entries {
            let vaultPathString = try XCTUnwrap(entry["vault_path"] as? String)
            let expectedPath = try FieldPath(validating: vaultPathString)
            let labelsByLocale = try XCTUnwrap(entry["labels"] as? [String: [String]])
            for variants in labelsByLocale.values {
                for variant in variants {
                    attempted += 1
                    if dictionary.lookup(normalizedLabel: LabelNormalizer.normalize(variant)) == expectedPath {
                        correct += 1
                    }
                }
            }
        }

        let precision = Double(correct) / Double(attempted)
        XCTAssertGreaterThanOrEqual(precision, 0.95, "dictionary precision \(precision) below NFR-A1's 95% bar (\(correct)/\(attempted))")
    }
}
