import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class RelationshipsViewModelTests: XCTestCase {
    private func makePerson(_ client: FakeVaultClient, name: String) async throws -> PersonID {
        let id = PersonID()
        let ticket = PolicyTicket(operation: .write, personID: id, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data())
        let person = try await client.createPerson(Person(id: id, kind: .person, displayName: name), ticket: ticket)
        return person.id
    }

    func testAddAndRemoveRelationship() async throws {
        let client = FakeVaultClient()
        let priya = try await makePerson(client, name: "Priya")
        let sam = try await makePerson(client, name: "Sam")
        let tickets = MockTicketProvider()
        let viewModel = RelationshipsViewModel(personID: priya, client: client, tickets: tickets)

        await viewModel.addRelationship(to: sam, kind: .spouse)
        XCTAssertEqual(viewModel.edges.count, 1)
        XCTAssertEqual(viewModel.edges.first?.kind, .spouse)

        await viewModel.removeRelationship(viewModel.edges[0])
        XCTAssertTrue(viewModel.edges.isEmpty)
    }

    func testRefreshReflectsClientState() async throws {
        let client = FakeVaultClient()
        let priya = try await makePerson(client, name: "Priya")
        let child = try await makePerson(client, name: "Child")
        let ticket = PolicyTicket(operation: .write, personID: priya, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data())
        try await client.addRelationship(RelationshipEdge(from: priya, to: child, kind: .child), ticket: ticket)

        let tickets = MockTicketProvider()
        let viewModel = RelationshipsViewModel(personID: priya, client: client, tickets: tickets)
        await viewModel.refresh()

        XCTAssertEqual(viewModel.edges.count, 1)
    }
}
