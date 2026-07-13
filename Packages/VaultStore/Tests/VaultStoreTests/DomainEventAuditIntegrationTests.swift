import XCTest
import VaultAPI
import Platform
import AuditLog
@testable import VaultStore

/// P0-15 integration tier (`*IntegrationTests`, picked up by
/// `Scripts/verify-integration.sh` automatically): exercises the full
/// publish -> durable-append path P1-18 wires up, not just the adapter's
/// mapping logic in isolation.
final class DomainEventAuditIntegrationTests: XCTestCase {
    func testPrivilegedVaultWriteProducesADurableChainValidAuditEntryBeforeReturning() async throws {
        let harness = try VaultStoreTestFactory.makeHarness()
        defer { harness.cleanUp() }
        try await harness.masterKeyManager.provision()

        let auditDirectory = harness.directory.appendingPathComponent("audit", isDirectory: true)
        let auditLogStore = try AuditLogStore(directory: auditDirectory)
        let bus = DomainEventBus()
        await bus.subscribe(AuditLogDomainEventSubscriber(auditLogStore: auditLogStore))

        let store = harness.makeStore(domainEventBus: bus)
        try await store.unlock()

        let person = Person(kind: .person, displayName: "Priya Shah")
        let createTicket = PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        _ = try await store.createPerson(person, ticket: createTicket)

        let path = try FieldPath(validating: "identity.nationality")
        let writeTicket = PolicyTicket(
            operation: .write, personID: person.id, scopedPaths: [path],
            issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        // By the time this returns, `DomainEventBus.publish` has already
        // awaited `AuditLogDomainEventSubscriber.handle`, so the audit
        // entry below is on disk before this call is considered committed.
        try await store.writeField(ProfileField(personID: person.id, path: path, value: .enumeration("CA")), ticket: writeTicket)

        let entries = try await auditLogStore.entries(matching: AuditEntryFilter(eventTypes: [.vaultWrite]))
        let matching = entries.first { $0.ticketID == writeTicket.id.uuidString && $0.fieldPath == path.description }
        XCTAssertNotNil(matching, "expected a durable vaultWrite audit entry for the writeField call")
        let chainValid = await auditLogStore.verifyChain()
        XCTAssertTrue(chainValid)
    }
}
