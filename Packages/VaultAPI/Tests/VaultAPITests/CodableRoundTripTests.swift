import XCTest
@testable import VaultAPI

/// Every DTO that crosses XPC must round-trip through JSON losslessly
/// (root CLAUDE.md §4: "Sendable/Codable for anything crossing XPC").
final class CodableRoundTripTests: XCTestCase {
    private func assertRoundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }

    func testFieldPathRoundTrip() throws {
        try assertRoundTrip(FieldPath(validating: "identity.passport.number"))
    }

    func testSecureBytesRoundTrip() throws {
        try assertRoundTrip(SecureBytes(utf8: "X1234567"))
    }

    func testSecureBytesNeverExposesPlaintextInDescription() {
        let secret = SecureBytes(utf8: "super-secret-ssn")
        XCTAssertFalse("\(secret)".contains("super-secret-ssn"))
        XCTAssertEqual(secret.exposeAsPlaintext(), "super-secret-ssn")
    }

    func testFieldValueRoundTrip() throws {
        try assertRoundTrip(FieldValue.string(SecureBytes(utf8: "Jane Doe")))
        try assertRoundTrip(FieldValue.date(Date(timeIntervalSince1970: 12_345)))
        try assertRoundTrip(FieldValue.number(42.5))
        try assertRoundTrip(FieldValue.enumeration("married"))
        try assertRoundTrip(FieldValue.list([.string(SecureBytes(utf8: "a")), .number(1)]))
    }

    func testProvenanceRoundTrip() throws {
        try assertRoundTrip(Provenance.manual)
        try assertRoundTrip(Provenance.document(
            documentID: UUID(), page: 2,
            region: ProvenanceRegion(originX: 0.1, originY: 0.2, width: 0.3, height: 0.05), confidence: 0.92
        ))
    }

    func testPersonRoundTrip() throws {
        try assertRoundTrip(Person(kind: .person, displayName: "Priya Shah"))
        try assertRoundTrip(Person(kind: .organization, displayName: "Acme LLC"))
    }

    func testRelationshipEdgeRoundTrip() throws {
        try assertRoundTrip(RelationshipEdge(from: PersonID(), to: PersonID(), kind: .spouse))
        try assertRoundTrip(RelationshipEdge(from: PersonID(), to: PersonID(), kind: .other("godparent")))
    }

    func testHistoryEntryRoundTrip() throws {
        let path = try FieldPath(validating: "employment.employer.name")
        try assertRoundTrip(HistoryEntry(
            personID: PersonID(),
            category: .employer,
            range: DateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1_000)),
            fields: [HistoryFieldEntry(path: path, value: .string(SecureBytes(utf8: "Acme LLC")))]
        ))
    }

    func testProfileFieldRoundTrip() throws {
        let path = try FieldPath(validating: "identity.passport.number")
        try assertRoundTrip(ProfileField(
            personID: PersonID(), path: path, value: .string(SecureBytes(utf8: "X1234567")),
            sensitivity: .sensitive, aliases: ["passport #"], verifiedAt: Date(timeIntervalSince1970: 500),
            provenance: .manual
        ))
    }

    func testPolicyTicketRoundTrip() throws {
        let path = try FieldPath(validating: "identity.passport.number")
        try assertRoundTrip(PolicyTicket(
            operation: .read, personID: PersonID(), scopedPaths: [path],
            issuedAt: Date(timeIntervalSince1970: 0), expiresAt: Date(timeIntervalSince1970: 300),
            signature: Data([0x01, 0x02, 0x03])
        ))
    }

    func testFieldSummaryRoundTrip() throws {
        let path = try FieldPath(validating: "identity.date_of_birth")
        try assertRoundTrip(FieldSummary(
            path: path, isPresent: true, sensitivity: .standard,
            verifiedAt: Date(timeIntervalSince1970: 0), valueFingerprint: "abc123"
        ))
    }

    func testVaultErrorRoundTrip() throws {
        try assertRoundTrip(VaultError.personNotFound(PersonID()))
        try assertRoundTrip(VaultError.ticketOperationMismatch(expected: .read, got: .write))
    }
}
