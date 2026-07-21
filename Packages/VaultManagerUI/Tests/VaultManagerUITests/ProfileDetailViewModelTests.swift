import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class ProfileDetailViewModelTests: XCTestCase {
    private struct Fixture {
        let viewModel: ProfileDetailViewModel
        let client: FakeVaultClient
        let clock: InMemoryAuthFreshnessClock
        let personID: PersonID
    }

    private func makeFixture(locked: Bool = false) async throws -> Fixture {
        let client = FakeVaultClient()
        let clock = InMemoryAuthFreshnessClock()
        let tickets = FakeTicketIssuer(authFreshnessClock: clock)
        let personID = PersonID()
        let bootstrapTicket = PolicyTicket(
            operation: .write, personID: personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        _ = try await client.createPerson(Person(id: personID, kind: .person, displayName: "Priya"), ticket: bootstrapTicket)
        await client.setLockState(locked ? .locked : .unlocked)
        return Fixture(
            viewModel: ProfileDetailViewModel(personID: personID, client: client, tickets: tickets),
            client: client, clock: clock, personID: personID
        )
    }

    private func path(_ raw: String) throws -> FieldPath { try FieldPath(validating: raw) }

    func testWriteStandardFieldIsImmediatelyVisibleUnmasked() async throws {
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.legal_name.first")
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "Priya")), sensitivity: .standard)

        let field = fixture.viewModel.fields[fieldPath]
        XCTAssertEqual(field?.isMasked, false)
        XCTAssertEqual(field?.revealedValue, .string(SecureBytes(utf8: "Priya")))
    }

    func testWriteSensitiveFieldWithStaleAuthRequiresReauth() async throws {
        // Writing a .sensitive field is gated by the same freshness rule as
        // reading one (PolicyRules row 3 doesn't distinguish operation).
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.ssn")
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        XCTAssertTrue(fixture.viewModel.needsReauth)
        XCTAssertNil(fixture.viewModel.fields[fieldPath])
    }

    func testWriteSensitiveFieldStartsMasked() async throws {
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.ssn")
        await fixture.clock.noteAuthenticated(at: Date())
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        let field = fixture.viewModel.fields[fieldPath]
        XCTAssertEqual(field?.isMasked, true)
        XCTAssertNil(field?.revealedValue)
    }

    func testRevealSensitiveFieldRequiresReauthWhenAuthIsStale() async throws {
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.ssn")
        await fixture.clock.noteAuthenticated(at: Date())
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)
        await fixture.clock.noteAuthenticated(at: .distantPast) // auth goes stale again before reveal

        await fixture.viewModel.reveal(fieldPath)

        XCTAssertTrue(fixture.viewModel.needsReauth)
        XCTAssertTrue(fixture.viewModel.fields[fieldPath]?.isMasked ?? false)
    }

    func testRevealSensitiveFieldSucceedsWithFreshAuth() async throws {
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.ssn")
        await fixture.clock.noteAuthenticated(at: Date())
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)

        await fixture.viewModel.reveal(fieldPath)

        XCTAssertFalse(fixture.viewModel.needsReauth)
        XCTAssertEqual(fixture.viewModel.fields[fieldPath]?.revealedValue, .string(SecureBytes(utf8: "000-00-0000")))
    }

    func testMaskRestoresMaskedStateWithoutDeletingField() async throws {
        let fixture = try await makeFixture()
        let fieldPath = try path("identity.ssn")
        await fixture.clock.noteAuthenticated(at: Date())
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "000-00-0000")), sensitivity: .sensitive)
        await fixture.viewModel.reveal(fieldPath)

        fixture.viewModel.mask(fieldPath)

        let field = fixture.viewModel.fields[fieldPath]
        XCTAssertEqual(field?.isMasked, true)
        XCTAssertNotNil(field) // still present, just re-masked
    }

    func testWriteFieldWhileLockedFailsAndSurfacesError() async throws {
        let fixture = try await makeFixture(locked: true)
        let fieldPath = try path("identity.legal_name.first")
        await fixture.viewModel.writeField(path: fieldPath, value: .string(SecureBytes(utf8: "Priya")), sensitivity: .standard)

        XCTAssertNil(fixture.viewModel.fields[fieldPath])
        XCTAssertNotNil(fixture.viewModel.errorMessage)
    }

    func testCustomFieldPathRoundTrips() async throws {
        let fixture = try await makeFixture()
        let customPath = try FieldPath.custom(["boat", "hull_id"])
        await fixture.viewModel.writeField(path: customPath, value: .string(SecureBytes(utf8: "HULL-1")), sensitivity: .standard)

        XCTAssertEqual(fixture.viewModel.fields[customPath]?.revealedValue, .string(SecureBytes(utf8: "HULL-1")))
    }

    func testOverlappingHistoryEntriesAreDetected() async throws {
        let fixture = try await makeFixture()
        let ticket = PolicyTicket(
            operation: .write, personID: fixture.personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        let jan = Date(timeIntervalSince1970: 0)
        let june = jan.addingTimeInterval(60 * 60 * 24 * 180)
        let mar = jan.addingTimeInterval(60 * 60 * 24 * 60)
        let dec = jan.addingTimeInterval(60 * 60 * 24 * 340)
        let entry = HistoryEntry(personID: fixture.personID, category: .employer, range: DateRange(start: jan, end: june))
        try await fixture.client.writeHistoryEntry(entry, ticket: ticket)
        await fixture.viewModel.loadHistory(.employer)

        let overlapping = fixture.viewModel.overlaps(with: DateRange(start: mar, end: dec), category: .employer)

        XCTAssertEqual(overlapping.map(\.id), [entry.id])
    }

    func testNonOverlappingHistoryEntriesAreNotFlagged() async throws {
        let fixture = try await makeFixture()
        let ticket = PolicyTicket(
            operation: .write, personID: fixture.personID, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        let jan = Date(timeIntervalSince1970: 0)
        let june = jan.addingTimeInterval(60 * 60 * 24 * 180)
        let july = june.addingTimeInterval(60 * 60 * 24)
        let dec = jan.addingTimeInterval(60 * 60 * 24 * 340)
        let entry = HistoryEntry(personID: fixture.personID, category: .employer, range: DateRange(start: jan, end: june))
        try await fixture.client.writeHistoryEntry(entry, ticket: ticket)
        await fixture.viewModel.loadHistory(.employer)

        let overlapping = fixture.viewModel.overlaps(with: DateRange(start: july, end: dec), category: .employer)

        XCTAssertTrue(overlapping.isEmpty)
    }
}
