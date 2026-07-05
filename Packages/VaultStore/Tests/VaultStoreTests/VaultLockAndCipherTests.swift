import XCTest
import VaultAPI
@testable import VaultStore

/// Covers the parts of the Acceptance Criteria the shared conformance suite
/// doesn't reach: the DB file is genuinely unreadable ciphertext at rest,
/// and calls against a locked vault are rejected rather than silently
/// no-op'd (CLAUDE.md §15: "vault-locked is a normal state" — but it must
/// still be surfaced, never swallowed).
final class VaultLockAndCipherTests: XCTestCase {
    func testDatabaseFileIsUnreadableCiphertextWithoutUnlock() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()

        let ticket = PolicyTicket(
            operation: .write, personID: PersonID(), scopedPaths: [],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        _ = try await store.createPerson(Person(id: ticket.personID, kind: .person, displayName: "Priya Shah"), ticket: ticket)
        await store.lock()

        let raw = try Data(contentsOf: harness.dbURL)
        // An unencrypted SQLite file always starts with this 16-byte magic
        // header; SQLCipher's whole-file encryption means a keyless read
        // sees neither this header nor "Priya Shah" anywhere in the bytes.
        let sqliteMagic = Data("SQLite format 3\0".utf8)
        XCTAssertNotEqual(raw.prefix(sqliteMagic.count), sqliteMagic, "DB file must not be readable as plaintext SQLite without the key")
        XCTAssertNil(raw.range(of: Data("Priya Shah".utf8)), "plaintext value must not appear anywhere in the ciphertext file")
    }

    func testCallsAgainstLockedVaultAreRejected() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()

        let ticket = PolicyTicket(
            operation: .read, personID: PersonID(), scopedPaths: [],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        do {
            _ = try await store.person(ticket.personID, ticket: ticket)
            XCTFail("a call against a never-unlocked store must throw, not silently proceed")
        } catch let error as VaultError {
            XCTAssertEqual(error, .vaultLocked)
        }

        try await store.unlock()
        await store.lock()
        do {
            _ = try await store.person(ticket.personID, ticket: ticket)
            XCTFail("a call after lock() must throw, not silently proceed")
        } catch let error as VaultError {
            XCTAssertEqual(error, .vaultLocked)
        }
    }

    func testReopeningAfterCloseIsDurable() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()

        let person = Person(kind: .person, displayName: "Priya Shah")
        let writeTicket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        let readTicket = PolicyTicket(
            operation: .read, personID: person.id, scopedPaths: [],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        do {
            let store = harness.makeStore()
            try await store.unlock()
            _ = try await store.createPerson(person, ticket: writeTicket)
            await store.lock()
        }

        // A fresh store instance over the same on-disk file + master key,
        // simulating a process relaunch.
        let reopened = harness.makeStore()
        try await reopened.unlock()
        let fetched = try await reopened.person(person.id, ticket: readTicket)
        XCTAssertEqual(fetched.id, person.id)
        XCTAssertEqual(fetched.displayName, "Priya Shah")
    }
}
