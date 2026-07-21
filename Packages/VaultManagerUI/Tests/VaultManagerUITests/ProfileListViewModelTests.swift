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

    func testDeletePersonRemovesFromLocalListAndRelationships() async throws {
        let (viewModel, _) = await makeViewModel()
        let createdPriya = await viewModel.createPerson(kind: .person, displayName: "Priya")
        let createdSam = await viewModel.createPerson(kind: .person, displayName: "Sam")
        let priya = try XCTUnwrap(createdPriya)
        let sam = try XCTUnwrap(createdSam)
        await viewModel.addRelationship(from: priya.id, to: sam.id, kind: .spouse)

        await viewModel.deletePerson(priya.id)

        XCTAssertFalse(viewModel.persons.contains { $0.id == priya.id })
        XCTAssertNil(viewModel.relationships[priya.id])
    }

    func testAddRelationshipIsReflectedLocally() async throws {
        let (viewModel, _) = await makeViewModel()
        let createdPriya = await viewModel.createPerson(kind: .person, displayName: "Priya")
        let createdSam = await viewModel.createPerson(kind: .person, displayName: "Sam")
        let priya = try XCTUnwrap(createdPriya)
        let sam = try XCTUnwrap(createdSam)

        await viewModel.addRelationship(from: priya.id, to: sam.id, kind: .spouse)

        XCTAssertEqual(viewModel.relationships[priya.id]?.count, 1)
        XCTAssertEqual(viewModel.relationships[priya.id]?.first?.kind, .spouse)
    }

    func testRefreshRelationshipsPullsFromClient() async throws {
        let (viewModel, client) = await makeViewModel()
        let createdPriya = await viewModel.createPerson(kind: .person, displayName: "Priya")
        let createdSam = await viewModel.createPerson(kind: .person, displayName: "Sam")
        let priya = try XCTUnwrap(createdPriya)
        let sam = try XCTUnwrap(createdSam)
        let ticket = PolicyTicket(
            operation: .write, personID: priya.id, issuedAt: Date(), expiresAt: Date().addingTimeInterval(60), signature: Data()
        )
        try await client.addRelationship(RelationshipEdge(from: priya.id, to: sam.id, kind: .child), ticket: ticket)

        await viewModel.refreshRelationships()

        XCTAssertEqual(viewModel.relationships[priya.id]?.count, 1)
    }
}
