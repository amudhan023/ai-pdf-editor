import XCTest
import VaultAPI
@testable import VaultStore

final class MigrationAndTransactionTests: XCTestCase {
    /// Two `SQLCipherVaultStore.unlock()` calls against the same file run
    /// `VaultMigrations.migrator` twice; GRDB's migrator must no-op the
    /// second time rather than erroring on "table already exists."
    func testMigratorIsIdempotentAcrossReopens() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()

        let store = harness.makeStore()
        try await store.unlock()
        await store.lock()

        // Re-running unlock (and therefore the migrator) a second time
        // against the same on-disk file must not throw.
        try await store.unlock()
    }

    /// A `writeField` for a person that doesn't exist must fail the whole
    /// write transaction — proving the person-existence check and the
    /// insert are atomic, not a check-then-separately-commit race.
    func testFailedWriteDoesNotPartiallyCommit() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()

        let ghostPersonID = PersonID()
        let path = try FieldPath(validating: "identity.nationality")
        let field = ProfileField(personID: ghostPersonID, path: path, value: .enumeration("CA"))
        let writeTicket = PolicyTicket(
            operation: .write, personID: ghostPersonID, scopedPaths: [path],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        do {
            try await store.writeField(field, ticket: writeTicket)
            XCTFail("writing a field for a nonexistent person must throw")
        } catch let error as VaultError {
            XCTAssertEqual(error, .personNotFound(ghostPersonID))
        }

        let readTicket = PolicyTicket(
            operation: .read, personID: ghostPersonID, scopedPaths: [path],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        do {
            _ = try await store.readFields([path], for: ghostPersonID, ticket: readTicket)
            XCTFail("the field must not have been committed despite the failed transaction")
        } catch let error as VaultError {
            XCTAssertEqual(error, .fieldNotFound(path))
        }
    }
}
