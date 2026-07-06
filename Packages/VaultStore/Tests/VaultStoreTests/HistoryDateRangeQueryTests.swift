import XCTest
import VaultAPI
@testable import VaultStore

final class HistoryDateRangeQueryTests: XCTestCase {
    private func unlockedStore(name: String = #function) async throws -> (SQLCipherVaultStore, VaultStoreTestFactory.Harness) {
        let harness = try VaultStoreTestFactory.makeHarness(name: name)
        try await harness.masterKeyManager.provision()
        let store = harness.makeStore()
        try await store.unlock()
        return (store, harness)
    }

    private func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: 0).addingTimeInterval(TimeInterval(n) * 86_400)
    }

    func testOverlappingQueryReturnsOnlyEntriesThatOverlap() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))
        let writeTicket = PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        // Entry A: day 0-5 (before the query window, no overlap).
        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .employer, range: DateRange(start: day(0), end: day(5))),
            ticket: writeTicket
        )
        // Entry B: day 8-20 (overlaps the front edge of the query window).
        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .employer, range: DateRange(start: day(8), end: day(20))),
            ticket: writeTicket
        )
        // Entry C: ongoing from day 18 (no end date — must overlap any
        // query whose start is at or before "now").
        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .employer, range: DateRange(start: day(18), end: nil)),
            ticket: writeTicket
        )
        // Entry D: day 50-60, far outside the query window.
        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .employer, range: DateRange(start: day(50), end: day(60))),
            ticket: writeTicket
        )

        let readTicket = PolicyTicket(
            operation: .read, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        let results = try await store.historyEntries(
            category: .employer,
            overlapping: DateRange(start: day(9), end: day(19)),
            for: person.id,
            ticket: readTicket
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.range.start), [day(8), day(18)])
    }

    func testOpenEndedQueryIncludesOngoingAndFutureEntries() async throws {
        let (store, harness) = try await unlockedStore()
        defer { harness.cleanUp() }

        let person = Person(kind: .person, displayName: "Priya Shah")
        _ = try await store.createPerson(person, ticket: PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        ))
        let writeTicket = PolicyTicket(
            operation: .write, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )

        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .address, range: DateRange(start: day(0), end: day(5))),
            ticket: writeTicket
        )
        try await store.writeHistoryEntry(
            HistoryEntry(personID: person.id, category: .address, range: DateRange(start: day(10), end: nil)),
            ticket: writeTicket
        )

        let readTicket = PolicyTicket(
            operation: .read, personID: person.id, issuedAt: Date(), expiresAt: Date(timeIntervalSinceNow: 300), signature: Data()
        )
        let results = try await store.historyEntries(
            category: .address,
            overlapping: DateRange(start: day(9), end: nil),
            for: person.id,
            ticket: readTicket
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.range.start, day(10))
    }
}
