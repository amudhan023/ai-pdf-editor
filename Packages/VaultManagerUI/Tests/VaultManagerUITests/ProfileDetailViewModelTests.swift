import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class ProfileDetailViewModelTests: XCTestCase {
    private func makeViewModel(locked: Bool = false) async -> (ProfileDetailViewModel, FakeVaultClient, InMemoryAuthFreshnessClock, PersonID) {
        let client = FakeVaultClient()
        let clock = InMemoryAuthFreshnessClock()
        let tickets = FakeTicketIssuer(authFreshnessClock: clock)
        let personID = PersonID()
        let bootstrapTicket = PolicyTicket(
            operation: .write, personID: personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        _ = try! await client.createPerson(Person(id: personID, kind: .person, displayName: "Priya"), ticket: bootstrapTicket)
        await client.setLockState(locked ? .locked : .unlocked)
        return (ProfileDetailViewModel(personID: personID, client: client, tickets: tickets), client, clock, personID)
    }

    private func path(_ raw: String) -> FieldPath { try! FieldPath(validating: raw) }

    func testWriteStandardFieldIsImmediatelyVisibleUnmasked() async {
        let (viewModel, _, _, _) = await makeViewModel()
        await viewModel.writeField(path: path("identity.legal_name.first"), value: .string(SecureBytes(utf8: "Priya")), sensitivity: .standard)

        let field = viewModel.fields[path("identity.legal_name.first")]
        XCTAssertEqual(field?.isMasked, false)
        XCTAssertEqual(field?.revealedValue, .string(SecureBytes(utf8: "Priya")))
    }

    func testWriteSensitiveFieldWithStaleAuthRequiresReauth() async {
        // Writing a .sensitive field is gated by the same freshness rule as
        // reading one (PolicyRules row 3 doesn't distinguish operation).
        let (viewModel, _, _, _) = await makeViewModel()
        await viewModel.writeField(path: path("identity.ssn"), value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        XCTAssertTrue(viewModel.needsReauth)
        XCTAssertNil(viewModel.fields[path("identity.ssn")])
    }

    func testWriteSensitiveFieldStartsMasked() async {
        let (viewModel, _, clock, _) = await makeViewModel()
        await clock.noteAuthenticated(at: Date())
        await viewModel.writeField(path: path("identity.ssn"), value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        let field = viewModel.fields[path("identity.ssn")]
        XCTAssertEqual(field?.isMasked, true)
        XCTAssertNil(field?.revealedValue)
    }

    func testRevealSensitiveFieldRequiresReauthWhenAuthIsStale() async {
        let (viewModel, _, clock, _) = await makeViewModel()
        await clock.noteAuthenticated(at: Date())
        await viewModel.writeField(path: path("identity.ssn"), value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)
        await clock.noteAuthenticated(at: .distantPast) // auth goes stale again before reveal

        await viewModel.reveal(path("identity.ssn"))

        XCTAssertTrue(viewModel.needsReauth)
        XCTAssertTrue(viewModel.fields[path("identity.ssn")]?.isMasked ?? false)
    }

    func testRevealSensitiveFieldSucceedsWithFreshAuth() async {
        let (viewModel, _, clock, _) = await makeViewModel()
        await clock.noteAuthenticated(at: Date())
        await viewModel.writeField(path: path("identity.ssn"), value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        await viewModel.reveal(path("identity.ssn"))

        XCTAssertFalse(viewModel.needsReauth)
        XCTAssertEqual(viewModel.fields[path("identity.ssn")]?.revealedValue, .string(SecureBytes(utf8: "000-00-0000")))
    }

    func testMaskRestoresMaskedStateWithoutDeletingField() async {
        let (viewModel, _, clock, _) = await makeViewModel()
        await clock.noteAuthenticated(at: Date())
        await viewModel.writeField(path: path("identity.ssn"), value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)
        await viewModel.reveal(path("identity.ssn"))

        viewModel.mask(path("identity.ssn"))

        let field = viewModel.fields[path("identity.ssn")]
        XCTAssertEqual(field?.isMasked, true)
        XCTAssertNotNil(field) // still present, just re-masked
    }

    func testWriteFieldWhileLockedFailsAndSurfacesError() async {
        let (viewModel, _, _, _) = await makeViewModel(locked: true)
        await viewModel.writeField(path: path("identity.legal_name.first"), value: .string(SecureBytes(utf8: "Priya")), sensitivity: .standard)

        XCTAssertNil(viewModel.fields[path("identity.legal_name.first")])
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCustomFieldPathRoundTrips() async {
        let (viewModel, _, _, _) = await makeViewModel()
        let customPath = try! FieldPath.custom(["boat", "hull_id"])
        await viewModel.writeField(path: customPath, value: .string(SecureBytes(utf8: "HULL-1")), sensitivity: .standard)

        XCTAssertEqual(viewModel.fields[customPath]?.revealedValue, .string(SecureBytes(utf8: "HULL-1")))
    }

    func testOverlappingHistoryEntriesAreDetected() async {
        let (viewModel, client, _, personID) = await makeViewModel()
        let ticket = PolicyTicket(
            operation: .write, personID: personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        let jan = Date(timeIntervalSince1970: 0)
        let june = jan.addingTimeInterval(60 * 60 * 24 * 180)
        let mar = jan.addingTimeInterval(60 * 60 * 24 * 60)
        let dec = jan.addingTimeInterval(60 * 60 * 24 * 340)
        let first = HistoryEntry(personID: personID, category: .employer, range: DateRange(start: jan, end: june))
        try! await client.writeHistoryEntry(first, ticket: ticket)
        await viewModel.loadHistory(.employer)

        let overlapping = viewModel.overlaps(with: DateRange(start: mar, end: dec), category: .employer)

        XCTAssertEqual(overlapping.map(\.id), [first.id])
    }

    func testNonOverlappingHistoryEntriesAreNotFlagged() async {
        let (viewModel, client, _, personID) = await makeViewModel()
        let ticket = PolicyTicket(
            operation: .write, personID: personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        let jan = Date(timeIntervalSince1970: 0)
        let june = jan.addingTimeInterval(60 * 60 * 24 * 180)
        let july = june.addingTimeInterval(60 * 60 * 24)
        let dec = jan.addingTimeInterval(60 * 60 * 24 * 340)
        let first = HistoryEntry(personID: personID, category: .employer, range: DateRange(start: jan, end: june))
        try! await client.writeHistoryEntry(first, ticket: ticket)
        await viewModel.loadHistory(.employer)

        let overlapping = viewModel.overlaps(with: DateRange(start: july, end: dec), category: .employer)

        XCTAssertTrue(overlapping.isEmpty)
    }
}
