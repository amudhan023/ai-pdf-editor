import XCTest
import VaultAPI
@testable import AutofillEngine

final class CompositeDictionaryTests: XCTestCase {
    func test_fullName_decomposesToFirstAndLastNamePaths() throws {
        let dictionary = try CompositeDictionary.bundled()
        let match = dictionary.lookup(normalizedLabel: LabelNormalizer.normalize("Full Name"))
        XCTAssertEqual(match?.parts, [
            try FieldPath(validating: "identity.legal_name.first"),
            try FieldPath(validating: "identity.legal_name.last")
        ])
    }

    func test_mailingAddress_decomposesToFiveAddressParts() throws {
        let dictionary = try CompositeDictionary.bundled()
        let match = dictionary.lookup(normalizedLabel: LabelNormalizer.normalize("Mailing Address"))
        XCTAssertEqual(match?.parts.count, 5)
        XCTAssertEqual(match?.parts.first, try FieldPath(validating: "contact.address.line1"))
    }

    func test_unrecognizedLabel_returnsNil() throws {
        let dictionary = try CompositeDictionary.bundled()
        XCTAssertNil(dictionary.lookup(normalizedLabel: LabelNormalizer.normalize("Preferred Shoe Size")))
    }

    func test_bareAddress_isNotComposite_singleLineDictionaryEntryStillApplies() throws {
        // Deliberate: "address" alone stays AliasDictionary's single-path
        // entry (contact.address.line1) — only the unambiguous multi-field
        // phrasings are composite here. See CompositeDictionary's header doc.
        let dictionary = try CompositeDictionary.bundled()
        XCTAssertNil(dictionary.lookup(normalizedLabel: LabelNormalizer.normalize("Address")))
    }
}
