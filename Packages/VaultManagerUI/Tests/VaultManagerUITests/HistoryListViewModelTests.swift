import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class HistoryListViewModelTests: XCTestCase {
    private func makePerson(_ client: FakeVaultClient) async throws -> PersonID {
        let id = PersonID()
        let ticket = PolicyTicket(operation: .write, personID: id, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data())
        let person = try await client.createPerson(Person(id: id, kind: .person, displayName: "Priya"), ticket: ticket)
        return person.id
    }

    func testOverlappingAddressEntriesAreFlagged() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let tickets = MockTicketProvider()
        let viewModel = HistoryListViewModel(personID: personID, category: .address, client: client, tickets: tickets)

        let jan1 = Date(timeIntervalSince1970: 0)
        let jun1 = jan1.addingTimeInterval(150 * 86400)
        let mar1 = jan1.addingTimeInterval(60 * 86400)
        let dec1 = jan1.addingTimeInterval(330 * 86400)

        await viewModel.addEntry(range: DateRange(start: jan1, end: jun1), fields: [])
        await viewModel.addEntry(range: DateRange(start: mar1, end: dec1), fields: [])

        XCTAssertEqual(viewModel.rows.count, 2)
        XCTAssertTrue(viewModel.rows.allSatisfy(\.overlapsAnother))
    }

    func testNonOverlappingEntriesAreNotFlagged() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let tickets = MockTicketProvider()
        let viewModel = HistoryListViewModel(personID: personID, category: .address, client: client, tickets: tickets)

        let jan1 = Date(timeIntervalSince1970: 0)
        let jun1 = jan1.addingTimeInterval(150 * 86400)
        let jul1 = jan1.addingTimeInterval(180 * 86400)

        await viewModel.addEntry(range: DateRange(start: jan1, end: jun1), fields: [])
        await viewModel.addEntry(range: DateRange(start: jul1, end: nil), fields: [])

        XCTAssertEqual(viewModel.rows.count, 2)
        XCTAssertTrue(viewModel.rows.allSatisfy { !$0.overlapsAnother })
    }

    func testDeleteEntryRemovesRow() async throws {
        let client = FakeVaultClient()
        let personID = try await makePerson(client)
        let tickets = MockTicketProvider()
        let viewModel = HistoryListViewModel(personID: personID, category: .employer, client: client, tickets: tickets)

        await viewModel.addEntry(range: DateRange(start: Date()), fields: [])
        let id = try XCTUnwrap(viewModel.rows.first?.id)

        await viewModel.deleteEntry(id)
        XCTAssertTrue(viewModel.rows.isEmpty)
    }
}
