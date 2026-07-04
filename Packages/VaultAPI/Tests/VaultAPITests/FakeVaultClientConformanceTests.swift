import XCTest
@testable import VaultAPI

/// Proves `FakeVaultClient` passes the shared conformance suite — the same
/// suite a real `VaultStore`/`Vault.xpc`-backed client must pass later
/// (this task's Acceptance Criteria).
final class FakeVaultClientConformanceTests: XCTestCase {
    func testProfileAndFieldCRUDConformance() async throws {
        let client = FakeVaultClient()
        try await VaultConformanceSuite.verifyProfileAndFieldCRUD(client, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testCompareReadConformance() async throws {
        let client = FakeVaultClient()
        try await VaultConformanceSuite.verifyCompareRead(client, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testTicketDisciplineConformance() async throws {
        let client = FakeVaultClient()
        try await VaultConformanceSuite.verifyTicketDiscipline(client, person: Person(kind: .person, displayName: "Priya Shah"))
    }

    func testCryptoShredConformance() async throws {
        let client = FakeVaultClient()
        try await VaultConformanceSuite.verifyCryptoShred(client, person: Person(kind: .person, displayName: "Priya Shah"))
    }
}
