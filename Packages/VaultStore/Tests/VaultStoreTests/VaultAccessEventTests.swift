import XCTest
import VaultAPI
@testable import VaultStore

final class VaultAccessEventTests: XCTestCase {
    private func unlockedStore(name: String = #function) async throws -> (SQLCipherVaultStore, VaultStoreTestFactory.Harness) {
        let harness = try VaultStoreTestFactory.makeHarness(name: name)
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()
        return (store, harness)
    }

    func testWriteFieldEmitsAccessEventWithPathAndTicketIDButNoValue() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))

        var iterator = store.accessEvents.makeAsyncIterator()
        _ = await iterator.next() // drain createPerson's own event

        let path = try FieldPath(validating: "identity.nationality")
        let ticket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [path],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        try await store.writeField(ProfileField(personID: person.id, path: path, value: .enumeration("CA")), ticket: ticket)

        let event = await iterator.next()
        XCTAssertEqual(event?.operation, .write)
        XCTAssertEqual(event?.personID, person.id)
        XCTAssertEqual(event?.paths, [path])
        XCTAssertEqual(event?.ticketID, ticket.id)
    }
}
