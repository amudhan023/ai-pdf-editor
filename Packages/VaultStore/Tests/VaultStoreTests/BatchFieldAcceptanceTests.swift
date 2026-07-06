import XCTest
import VaultAPI
@testable import VaultStore

/// `acceptFields` is the ingestion "accept set" batch write (P1-10): every
/// field in the batch must land, or none do.
final class BatchFieldAcceptanceTests: XCTestCase {
    private func unlockedStore(name: String = #function) async throws -> (SQLCipherVaultStore, VaultStoreTestFactory.Harness) {
        let harness = try VaultStoreTestFactory.makeHarness(name: name)
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()
        return (store, harness)
    }

    func testAcceptFieldsCommitsAllInOneTransaction() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))

        let path1 = try FieldPath(validating: "identity.passport.number")
        let path2 = try FieldPath(validating: "identity.nationality")
        let fields = [
            ProfileField(personID: person.id, path: path1, value: .string(SecureBytes(utf8: "X1234567"))),
            ProfileField(personID: person.id, path: path2, value: .enumeration("CA"))
        ]
        let ticket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [path1, path2],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        try await store.acceptFields(fields, ticket: ticket)

        let readTicket = PolicyTicket(
            operation: .read, personID: person.id, scopedPaths: [path1, path2],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        let read = try await store.readFields([path1, path2], for: person.id, ticket: readTicket)
        XCTAssertEqual(Set(read.map(\.path)), Set([path1, path2]))
    }

    func testAcceptFieldsRollsBackEntirelyOnMidBatchFailure() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))

        let path1 = try FieldPath(validating: "identity.passport.number")
        let ghostPersonID = PersonID()
        let path2 = try FieldPath(validating: "identity.nationality")
        let fields = [
            ProfileField(personID: person.id, path: path1, value: .string(SecureBytes(utf8: "X1234567"))),
            ProfileField(personID: ghostPersonID, path: path2, value: .enumeration("CA"))
        ]
        // A single ticket scoped to `person` covers the first field's path
        // but not the second field's person — the batch must reject before
        // ever opening the write transaction.
        let ticket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [path1, path2],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        do {
            try await store.acceptFields(fields, ticket: ticket)
            XCTFail("a batch containing a field scoped to a different person must be rejected")
        } catch {
            // expected
        }

        let readTicket = PolicyTicket(
            operation: .read, personID: person.id, scopedPaths: [path1],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        do {
            _ = try await store.readFields([path1], for: person.id, ticket: readTicket)
            XCTFail("no field from the rejected batch must have been committed")
        } catch let error as VaultError {
            XCTAssertEqual(error, .fieldNotFound(path1))
        }
    }

    func testAcceptFieldsRollsBackWhenAPersonDoesNotExist() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))

        let path1 = try FieldPath(validating: "identity.passport.number")
        let path2 = try FieldPath(validating: "identity.nationality")
        // Both fields pass ticket scoping (same person), but the person is
        // deleted between minting the ticket and the write landing — the
        // in-transaction existence check must still fail the whole batch.
        try await store.deletePerson(person.id, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))

        let fields = [
            ProfileField(personID: person.id, path: path1, value: .string(SecureBytes(utf8: "X1234567"))),
            ProfileField(personID: person.id, path: path2, value: .enumeration("CA"))
        ]
        let ticket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [path1, path2],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        do {
            try await store.acceptFields(fields, ticket: ticket)
            XCTFail("a batch for a nonexistent person must fail entirely")
        } catch let error as VaultError {
            XCTAssertEqual(error, .personNotFound(person.id))
        }
    }
}
