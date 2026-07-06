import XCTest
import VaultAPI
@testable import VaultStore

/// `person`'s child rows (`profileField`, `historyEntry` +
/// `historyFieldEntry`, `relationshipEdge`) declare `ON DELETE CASCADE`
/// (`VaultMigrations` v1) — these tests pin that deleting a person actually
/// removes its dependents rather than leaving orphan rows (P1-10's "delete-
/// person cascade rules").
final class PersonCascadeDeleteTests: XCTestCase {
    private func unlockedStore(name: String = #function) async throws -> (SQLCipherVaultStore, VaultStoreTestFactory.Harness) {
        let harness = try VaultStoreTestFactory.makeHarness(name: name)
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()
        return (store, harness)
    }

    func testDeletingPersonCascadesFieldsHistoryAndRelationships() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let personA = Person(kind: .person, displayName: "Priya Shah")
        let personB = Person(kind: .person, displayName: "Arjun Shah")
        let writeTicketFor: (PersonID) -> PolicyTicket = { id in
            PolicyTicket(operation: .write, personID: id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data())
        }
        _ = try await store.createPerson(personA, ticket: writeTicketFor(personA.id))
        _ = try await store.createPerson(personB, ticket: writeTicketFor(personB.id))

        let path = try FieldPath(validating: "identity.nationality")
        try await store.writeField(
            ProfileField(personID: personA.id, path: path, value: .enumeration("CA")),
            ticket: PolicyTicket(
                operation: .write, personID: personA.id, scopedPaths: [path],
                issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
            )
        )
        try await store.writeHistoryEntry(
            HistoryEntry(personID: personA.id, category: .employer, range: DateRange(start: Date(), end: nil)),
            ticket: writeTicketFor(personA.id)
        )
        try await store.addRelationship(RelationshipEdge(from: personA.id, to: personB.id, kind: .spouse), ticket: writeTicketFor(personA.id))

        try await store.deletePerson(personA.id, ticket: writeTicketFor(personA.id))

        // The relationship must be gone from B's side too, even though B
        // itself was never deleted.
        let relationshipsForB = try await store.relationships(
            for: personB.id,
            ticket: PolicyTicket(operation: .read, personID: personB.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data())
        )
        XCTAssertTrue(relationshipsForB.isEmpty)

        // person A itself no longer exists, so its field/history rows are
        // checked via `compareRead`/`historyEntries`, whose structural
        // ticket checks don't require an existing person row.
        let compareResult = try await store.compareRead(
            [path], for: personA.id,
            ticket: PolicyTicket(operation: .compareRead, personID: personA.id, scopedPaths: [path], issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data())
        )
        XCTAssertEqual(compareResult.first?.isPresent, false)

        let historyForA = try await store.historyEntries(
            category: .employer, for: personA.id,
            ticket: PolicyTicket(operation: .read, personID: personA.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data())
        )
        XCTAssertTrue(historyForA.isEmpty)
    }
}
