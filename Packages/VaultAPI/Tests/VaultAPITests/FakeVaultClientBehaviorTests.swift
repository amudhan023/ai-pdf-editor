import XCTest
@testable import VaultAPI

/// Behavior not covered by the generic conformance suite: locked-vault
/// gating (fake-only `setLockState`, since real unlock is biometric and out
/// of this protocol's reach), history-entry and relationship CRUD, and
/// person deletion cascading to owned data.
final class FakeVaultClientBehaviorTests: XCTestCase {
    private func ticket(_ operation: VaultOperation, person: PersonID, paths: [FieldPath] = []) -> PolicyTicket {
        let now = Date()
        return PolicyTicket(
            operation: operation, personID: person, scopedPaths: paths,
            issuedAt: now, expiresAt: now.addingTimeInterval(300), signature: Data()
        )
    }

    func testLockedVaultRejectsEveryOperation() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))

        await client.setLockState(.locked)
        var threw = false
        do {
            _ = try await client.person(person.id, ticket: ticket(.read, person: person.id))
        } catch VaultError.vaultLocked {
            threw = true
        }
        XCTAssertTrue(threw, "expected vaultLocked while locked")

        await client.setLockState(.unlocked)
        let fetched = try await client.person(person.id, ticket: ticket(.read, person: person.id))
        XCTAssertEqual(fetched, person)
    }

    func testHistoryEntryCRUD() async throws {
        let client = FakeVaultClient()
        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await client.createPerson(person, ticket: ticket(.write, person: person.id))

        let entry = HistoryEntry(
            personID: person.id, category: .employer,
            range: DateRange(start: Date(timeIntervalSince1970: 0), end: nil)
        )
        try await client.writeHistoryEntry(entry, ticket: ticket(.write, person: person.id))

        let entries = try await client.historyEntries(category: .employer, for: person.id, ticket: ticket(.read, person: person.id))
        XCTAssertEqual(entries.map(\.id), [entry.id])

        try await client.deleteHistoryEntry(entry.id, for: person.id, ticket: ticket(.write, person: person.id))
        let afterDelete = try await client.historyEntries(category: .employer, for: person.id, ticket: ticket(.read, person: person.id))
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testRelationshipCRUD() async throws {
        let client = FakeVaultClient()
        let priya = Person(kind: .person, displayName: "Priya Shah")
        let sam = Person(kind: .person, displayName: "Sam Shah")
        _ = try await client.createPerson(priya, ticket: ticket(.write, person: priya.id))
        _ = try await client.createPerson(sam, ticket: ticket(.write, person: sam.id))

        let edge = RelationshipEdge(from: priya.id, to: sam.id, kind: .spouse)
        try await client.addRelationship(edge, ticket: ticket(.write, person: priya.id))

        let fromPriya = try await client.relationships(for: priya.id, ticket: ticket(.read, person: priya.id))
        XCTAssertEqual(fromPriya, [edge])
        let fromSam = try await client.relationships(for: sam.id, ticket: ticket(.read, person: sam.id))
        XCTAssertEqual(fromSam, [edge])

        try await client.removeRelationship(edge, ticket: ticket(.write, person: priya.id))
        let afterRemove = try await client.relationships(for: priya.id, ticket: ticket(.read, person: priya.id))
        XCTAssertTrue(afterRemove.isEmpty)
    }

    func testDeletePersonCascadesFieldsHistoryAndRelationships() async throws {
        let client = FakeVaultClient()
        let priya = Person(kind: .person, displayName: "Priya Shah")
        let sam = Person(kind: .person, displayName: "Sam Shah")
        _ = try await client.createPerson(priya, ticket: ticket(.write, person: priya.id))
        _ = try await client.createPerson(sam, ticket: ticket(.write, person: sam.id))

        let path = try FieldPath(validating: "identity.nationality")
        try await client.writeField(
            ProfileField(personID: priya.id, path: path, value: .enumeration("CA")),
            ticket: ticket(.write, person: priya.id, paths: [path])
        )
        try await client.addRelationship(
            RelationshipEdge(from: priya.id, to: sam.id, kind: .spouse), ticket: ticket(.write, person: priya.id)
        )

        try await client.deletePerson(priya.id, ticket: ticket(.write, person: priya.id))

        var personThrew = false
        do {
            _ = try await client.person(priya.id, ticket: ticket(.read, person: priya.id))
        } catch VaultError.personNotFound {
            personThrew = true
        }
        XCTAssertTrue(personThrew)

        let remainingEdges = try await client.relationships(for: sam.id, ticket: ticket(.read, person: sam.id))
        XCTAssertTrue(remainingEdges.isEmpty, "deleting a person must remove edges that reference it")
    }

    func testWriteFieldRejectsUnknownPerson() async throws {
        let client = FakeVaultClient()
        let unknown = PersonID()
        let path = try FieldPath(validating: "identity.nationality")
        var threw = false
        do {
            try await client.writeField(
                ProfileField(personID: unknown, path: path, value: .enumeration("CA")),
                ticket: ticket(.write, person: unknown, paths: [path])
            )
        } catch VaultError.personNotFound {
            threw = true
        }
        XCTAssertTrue(threw)
    }
}
