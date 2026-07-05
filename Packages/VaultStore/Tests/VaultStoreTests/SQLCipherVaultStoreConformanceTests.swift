import XCTest
import VaultAPI
@testable import VaultStore

/// Proves `SQLCipherVaultStore` passes the exact same `VaultConformanceSuite`
/// `FakeVaultClient` does — this task's Acceptance Criteria: "VaultAPI
/// conformance suite passes against the real service."
final class SQLCipherVaultStoreConformanceTests: XCTestCase {
    private func unlockedStore(name: String = #function) async throws -> (SQLCipherVaultStore, VaultStoreTestFactory.Harness) {
        let harness = try VaultStoreTestFactory.makeHarness(name: name)
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()
        return (store, harness)
    }

    func testProfileAndFieldCRUDConformance() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }
        try await VaultConformanceSuite.verifyProfileAndFieldCRUD(store, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testCompareReadConformance() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }
        try await VaultConformanceSuite.verifyCompareRead(store, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testTicketDisciplineConformance() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }
        try await VaultConformanceSuite.verifyTicketDiscipline(store, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testCryptoShredConformance() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }
        try await VaultConformanceSuite.verifyCryptoShred(store, person: Person(kind: .person, displayName: "Priya Shah"))
    }
}
