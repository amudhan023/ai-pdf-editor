import XCTest
import VaultAPI
@testable import PrivacyDashboard

final class StorageSummaryServiceTests: XCTestCase {
    private func compareReadTicket(person: PersonID) -> PolicyTicket {
        let now = Date()
        let allSections = FieldSection.allCases.compactMap { try? FieldPath(validating: $0.rawValue) }
        return PolicyTicket(
            operation: .compareRead, personID: person, scopedPaths: allSections,
            issuedAt: now, expiresAt: now.addingTimeInterval(300), signature: Data()
        )
    }

    private func writeTicket(person: PersonID) -> PolicyTicket {
        let now = Date()
        let allSections = FieldSection.allCases.compactMap { try? FieldPath(validating: $0.rawValue) }
        return PolicyTicket(
            operation: .write, personID: person, scopedPaths: allSections,
            issuedAt: now, expiresAt: now.addingTimeInterval(300), signature: Data()
        )
    }

    func testFreshProfileHasZeroCountsEverywhere() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: writeTicket(person: person.id))

        let service = StorageSummaryService(client: client)
        let summary = try await service.summarize(person, ticket: compareReadTicket(person: person.id))

        XCTAssertEqual(summary.totalFieldsPresent, 0)
        XCTAssertEqual(summary.personID, person.id)
        XCTAssertEqual(summary.displayName, "Priya Shah")
    }

    func testWrittenFieldsAreCountedUnderTheirSection() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: writeTicket(person: person.id))

        try await client.writeField(
            ProfileField(
                personID: person.id, path: try FieldPath(validating: "identity.legal_name.first"),
                value: .string(SecureBytes(utf8: "Priya"))
            ),
            ticket: writeTicket(person: person.id)
        )
        try await client.writeField(
            ProfileField(
                personID: person.id, path: try FieldPath(validating: "contact.email.primary"),
                value: .string(SecureBytes(utf8: "priya@example.com"))
            ),
            ticket: writeTicket(person: person.id)
        )

        let service = StorageSummaryService(client: client)
        let summary = try await service.summarize(person, ticket: compareReadTicket(person: person.id))

        XCTAssertEqual(summary.sectionCounts[.identity], 1)
        XCTAssertEqual(summary.sectionCounts[.contact], 1)
        XCTAssertEqual(summary.sectionCounts[.financial], 0)
        XCTAssertEqual(summary.totalFieldsPresent, 2)
    }

    func testMultiPersonSummarizeUsesPerPersonTicket() async throws {
        let client = FakeVaultClient()
        let alice = Person(kind: .person, displayName: "Alice")
        let bob = Person(kind: .person, displayName: "Bob")
        _ = try await client.createPerson(alice, ticket: writeTicket(person: alice.id))
        _ = try await client.createPerson(bob, ticket: writeTicket(person: bob.id))

        try await client.writeField(
            ProfileField(
                personID: bob.id, path: try FieldPath(validating: "identity.legal_name.first"),
                value: .string(SecureBytes(utf8: "Bob"))
            ),
            ticket: writeTicket(person: bob.id)
        )

        let service = StorageSummaryService(client: client)
        let summaries = try await service.summarize([alice, bob], ticket: { self.compareReadTicket(person: $0) })

        XCTAssertEqual(summaries.first { $0.personID == alice.id }?.totalFieldsPresent, 0)
        XCTAssertEqual(summaries.first { $0.personID == bob.id }?.totalFieldsPresent, 1)
    }
}
