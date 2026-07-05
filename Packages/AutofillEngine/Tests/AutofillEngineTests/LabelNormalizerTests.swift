import XCTest
@testable import AutofillEngine

final class LabelNormalizerTests: XCTestCase {
    func test_lowercasesAndTrimsPunctuation() {
        XCTAssertEqual(LabelNormalizer.normalize("First Name:"), "first name")
        XCTAssertEqual(LabelNormalizer.normalize("FIRST NAME*"), "first name")
    }

    func test_collapsesInternalWhitespace() {
        XCTAssertEqual(LabelNormalizer.normalize("First   Name"), "first name")
        XCTAssertEqual(LabelNormalizer.normalize("  First Name  "), "first name")
    }

    func test_expandsKnownAbbreviations() {
        XCTAssertEqual(LabelNormalizer.normalize("DOB"), "date of birth")
        XCTAssertEqual(LabelNormalizer.normalize("Tel"), "phone")
        XCTAssertEqual(LabelNormalizer.normalize("Addr"), "address")
    }

    func test_doesNotMangleWordsThatContainButAreNotAbbreviations() {
        XCTAssertEqual(LabelNormalizer.normalize("Address"), "address")
    }

    func test_stripsSlashesAndParenthesesAsSeparators() {
        XCTAssertEqual(LabelNormalizer.normalize("State/Province"), "state province")
        XCTAssertEqual(LabelNormalizer.normalize("Zip (Postal Code)"), "zip postal code")
    }

    func test_isIdempotent() {
        let once = LabelNormalizer.normalize("  FIRST NAME:  ")
        XCTAssertEqual(LabelNormalizer.normalize(once), once)
    }
}
