import XCTest
@testable import VaultAPI

/// Path parsing/validation tests (this task's Testing Requirements).
final class FieldPathTests: XCTestCase {
    func testValidPathParses() throws {
        let path = try FieldPath(validating: "identity.passport.number")
        XCTAssertEqual(path.section, .identity)
        XCTAssertEqual(path.segments, ["identity", "passport", "number"])
        XCTAssertEqual(path.description, "identity.passport.number")
    }

    func testSingleSegmentSectionPathParses() throws {
        let path = try FieldPath(validating: "identity")
        XCTAssertEqual(path.section, .identity)
        XCTAssertEqual(path.segments, ["identity"])
    }

    func testUnknownSectionRejected() {
        XCTAssertThrowsError(try FieldPath(validating: "vehicle.vin")) { error in
            guard case VaultError.invalidFieldPath("vehicle.vin") = error else {
                return XCTFail("expected invalidFieldPath, got \(error)")
            }
        }
    }

    func testEmptySegmentRejected() {
        XCTAssertThrowsError(try FieldPath(validating: "identity..number"))
    }

    func testUppercaseRejected() {
        XCTAssertThrowsError(try FieldPath(validating: "identity.Passport.number"))
    }

    func testHyphenRejected() {
        XCTAssertThrowsError(try FieldPath(validating: "identity.passport-number"))
    }

    func testCustomExtensionMechanism() throws {
        let path = try FieldPath.custom(["boat", "hull_id"])
        XCTAssertEqual(path.section, .custom)
        XCTAssertEqual(path.description, "custom.boat.hull_id")
    }

    func testCustomRejectsEmptyTrailingSegments() {
        XCTAssertThrowsError(try FieldPath.custom([]))
    }

    func testIsPrefixOf() throws {
        let section = try FieldPath(validating: "identity")
        let leaf = try FieldPath(validating: "identity.passport.number")
        let unrelated = try FieldPath(validating: "contact.email.primary")

        XCTAssertTrue(section.isPrefix(of: leaf))
        XCTAssertTrue(leaf.isPrefix(of: leaf))
        XCTAssertFalse(leaf.isPrefix(of: section))
        XCTAssertFalse(section.isPrefix(of: unrelated))
    }

    func testEquatableAndHashable() throws {
        let first = try FieldPath(validating: "identity.passport.number")
        let second = try FieldPath(validating: "identity.passport.number")
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.hashValue, second.hashValue)
    }
}
