import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class ProfileDetailViewModelTests: XCTestCase {
    private func writeTicket(personID: PersonID, paths: [FieldPath] = []) -> PolicyTicket {
        PolicyTicket(
            operation: .write, personID: personID, scopedPaths: paths,
            issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
    }

    private func makePerson(_ client: FakeVaultClient) async throws -> PersonID {
        let id = PersonID()
        let person = try await client.createPerson(
            Person(id: id, kind: .person, displayName: "Priya"), ticket: writeTicket(personID: id)
        )
        return person.id
    }

    func testStandardFieldLoadsValueEagerly() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let path = try FieldPath(validating: "contact.email.primary")
        try await client.writeField(
            ProfileField(personID: personID, path: path, value: .string(SecureBytes(utf8: "priya@example.com"))),
            ticket: writeTicket(personID: personID, paths: [path])
        )

        let tickets = MockTicketProvider()
        let auditing = MockRevealAuditing()
        let viewModel = ProfileDetailViewModel(personID: personID, client: client, tickets: tickets, auditing: auditing)
        await viewModel.load(catalog: [path])

        let state = try XCTUnwrap(viewModel.fields[path])
        XCTAssertTrue(state.isPresent)
        XCTAssertFalse(state.isMasked)
        XCTAssertEqual(state.revealedValue, .string(SecureBytes(utf8: "priya@example.com")))
    }

    func testSensitiveFieldStartsMaskedAndRevealFetchesValue() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let path = try FieldPath(validating: "identity.ssn")
        try await client.writeField(
            ProfileField(personID: personID, path: path, value: .string(SecureBytes(utf8: "123-45-6789")), sensitivity: .sensitive),
            ticket: writeTicket(personID: personID, paths: [path])
        )

        let tickets = MockTicketProvider()
        let auditing = MockRevealAuditing()
        let viewModel = ProfileDetailViewModel(personID: personID, client: client, tickets: tickets, auditing: auditing)
        await viewModel.load(catalog: [path])

        var state = try XCTUnwrap(viewModel.fields[path])
        XCTAssertTrue(state.isMasked)
        XCTAssertNil(state.revealedValue)
        XCTAssertEqual(auditing.reveals.count, 0)

        await viewModel.reveal(path)
        state = try XCTUnwrap(viewModel.fields[path])
        XCTAssertFalse(state.isMasked)
        XCTAssertEqual(state.revealedValue, .string(SecureBytes(utf8: "123-45-6789")))
        XCTAssertEqual(auditing.reveals.count, 1)
        XCTAssertEqual(auditing.reveals.first?.path, path)

        viewModel.rehide(path)
        state = try XCTUnwrap(viewModel.fields[path])
        XCTAssertTrue(state.isMasked)
        XCTAssertNil(state.revealedValue)
    }

    func testRevealRequiringReauthSurfacesAsUXStateNotError() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let path = try FieldPath(validating: "identity.ssn")
        try await client.writeField(
            ProfileField(personID: personID, path: path, value: .string(SecureBytes(utf8: "123-45-6789")), sensitivity: .sensitive),
            ticket: writeTicket(personID: personID, paths: [path])
        )

        let tickets = MockTicketProvider()
        await tickets.setShouldRequireReauth(true)
        let auditing = MockRevealAuditing()
        let viewModel = ProfileDetailViewModel(personID: personID, client: client, tickets: tickets, auditing: auditing)
        await viewModel.load(catalog: [path])
        await viewModel.reveal(path)

        XCTAssertEqual(viewModel.reauthRequired, path)
        XCTAssertNil(viewModel.fields[path]?.revealedValue)
        XCTAssertEqual(auditing.reveals.count, 0)
    }

    func testWriteValueThenDeleteRoundTrips() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let path = try FieldPath(validating: "custom.notes")

        let tickets = MockTicketProvider()
        let auditing = MockRevealAuditing()
        let viewModel = ProfileDetailViewModel(personID: personID, client: client, tickets: tickets, auditing: auditing)

        await viewModel.writeValue(path, value: .string(SecureBytes(utf8: "left front door key")), sensitivity: .standard)
        XCTAssertEqual(viewModel.fields[path]?.revealedValue, .string(SecureBytes(utf8: "left front door key")))

        await viewModel.deleteValue(path)
        XCTAssertEqual(viewModel.fields[path]?.isPresent, false)
    }
}
