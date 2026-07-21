import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class ProfileListViewModelTests: XCTestCase {
    private func makeViewModel(locked: Bool = false) async -> (ProfileListViewModel, FakeVaultClient) {
        let client = FakeVaultClient()
        await client.setLockState(locked ? .locked : .unlocked)
        let clock = InMemoryAuthFreshnessClock()
        let tickets = FakeTicketIssuer(authFreshnessClock: clock)
        return (ProfileListViewModel(client: client, tickets: tickets), client)
    }

    func testCreatePersonAddsToLocalList() async {
        let (viewModel, _) = await makeViewModel()
        let created = await viewModel.createPerson(kind: .person, displayName: "Priya")
        XCTAssertNotNil(created)
        XCTAssertEqual(viewModel.persons.map(\.displayName), ["Priya"])
    }

    func testCreatePersonWhileLockedFails() async {
        let (viewModel, _) = await makeViewModel(locked: true)
        let created = await viewModel.createPerson(kind: .person, displayName: "Priya")
        XCTAssertNil(created)
        XCTAssertTrue(viewModel.persons.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testDeletePersonRemovesFromLocalListAndRelationships() async {
        let (viewModel, _) = await makeViewModel()
        let person = (await viewModel.createPerson(kind: .person, displayName: "Priya"))!
        let other = (await viewModel.createPerson(kind: .person, displayName: "Sam"))!
        await viewModel.addRelationship(from: person.id, to: other.id, kind: .spouse)

        await viewModel.deletePerson(person.id)

        XCTAssertFalse(viewModel.persons.contains { $0.id == person.id })
        XCTAssertNil(viewModel.relationships[person.id])
    }

    func testAddRelationshipIsReflectedLocally() async {
        let (viewModel, _) = await makeViewModel()
        let a = (await viewModel.createPerson(kind: .person, displayName: "Priya"))!
        let b = (await viewModel.createPerson(kind: .person, displayName: "Sam"))!

        await viewModel.addRelationship(from: a.id, to: b.id, kind: .spouse)

        XCTAssertEqual(viewModel.relationships[a.id]?.count, 1)
        XCTAssertEqual(viewModel.relationships[a.id]?.first?.kind, .spouse)
    }

    func testRefreshRelationshipsPullsFromClient() async {
        let (viewModel, client) = await makeViewModel()
        let a = (await viewModel.createPerson(kind: .person, displayName: "Priya"))!
        let b = (await viewModel.createPerson(kind: .person, displayName: "Sam"))!
        let ticket = PolicyTicket(
            operation: .write, personID: a.id, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        try? await client.addRelationship(RelationshipEdge(from: a.id, to: b.id, kind: .child), ticket: ticket)

        await viewModel.refreshRelationships()

        XCTAssertEqual(viewModel.relationships[a.id]?.count, 1)
    }
}
