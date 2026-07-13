import XCTest
import VaultAPI
@testable import PrivacyDashboard

final class VaultActionsTests: XCTestCase {
    private func ticket(_ operation: VaultOperation, person: PersonID) -> PolicyTicket {
        let now = Date()
        let allSections = FieldSection.allCases.compactMap { try? FieldPath(validating: $0.rawValue) }
        return PolicyTicket(
            operation: operation, personID: person, scopedPaths: allSections,
            issuedAt: now, expiresAt: now.addingTimeInterval(300), signature: Data()
        )
    }

    // MARK: - VaultExportService

    func testExportSkipsAbsentFieldsAndIncludesPresentOnes() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))
        try await client.writeField(
            ProfileField(
                personID: person.id, path: try FieldPath(validating: "identity.legal_name.first"),
                value: .string(SecureBytes(utf8: "Priya"))
            ),
            ticket: ticket(.write, person: person.id)
        )

        let service = VaultExportService(client: client)
        let profile = try await service.exportedProfile(for: person, ticket: ticket(.read, person: person.id))

        XCTAssertEqual(profile.personID, person.id.value)
        XCTAssertEqual(profile.fields.map(\.path), ["identity.legal_name.first"])
    }

    func testExportJSONRoundTrips() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))
        try await client.writeField(
            ProfileField(
                personID: person.id, path: try FieldPath(validating: "contact.email.primary"),
                value: .string(SecureBytes(utf8: "priya@example.com"))
            ),
            ticket: ticket(.write, person: person.id)
        )

        let service = VaultExportService(client: client)
        let data = try await service.exportJSON(for: person, ticket: ticket(.read, person: person.id))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportedProfile.self, from: data)
        XCTAssertEqual(decoded.fields.map(\.path), ["contact.email.primary"])
    }

    // MARK: - SecureEraseViewModel

    func testConfirmEraseMismatchDoesNotAdvance() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))

        let viewModel = SecureEraseViewModel(client: client)
        await viewModel.beginConfirmation(for: person)

        let succeeded = await viewModel.confirmErase(
            typedName: "not the right name", person: person, ticket: ticket(.cryptoShred, person: person.id)
        )

        XCTAssertFalse(succeeded)
        let state = await viewModel.state
        XCTAssertEqual(state, .failed(.eraseConfirmationMismatch))
    }

    func testConfirmEraseRendersVaultUnreadable() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))

        let viewModel = SecureEraseViewModel(client: client)
        await viewModel.beginConfirmation(for: person)

        let succeeded = await viewModel.confirmErase(
            typedName: "Priya Shah", person: person, ticket: ticket(.cryptoShred, person: person.id)
        )

        XCTAssertTrue(succeeded)
        let state = await viewModel.state
        XCTAssertEqual(state, .erased)

        do {
            _ = try await client.person(person.id, ticket: ticket(.read, person: person.id))
            XCTFail("expected person(_:) to throw after crypto-shred")
        } catch VaultError.personNotFound(let id) {
            XCTAssertEqual(id, person.id)
        }
    }

    func testCancelReturnsToIdle() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")

        let viewModel = SecureEraseViewModel(client: client)
        await viewModel.beginConfirmation(for: person)
        await viewModel.cancel()

        let state = await viewModel.state
        XCTAssertEqual(state, .idle)
    }
}
