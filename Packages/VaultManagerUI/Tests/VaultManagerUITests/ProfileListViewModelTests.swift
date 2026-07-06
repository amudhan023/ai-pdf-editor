import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class ProfileListViewModelTests: XCTestCase {
    func testCreateAndRefreshRoundTrips() async throws {
        let client = FakeVaultClient()
        let tickets = MockTicketProvider()
        let viewModel = ProfileListViewModel(client: client, tickets: tickets)

        let created = await viewModel.createProfile(kind: .person, displayName: "Priya")
        let createdID = try XCTUnwrap(created?.id)
        XCTAssertEqual(viewModel.people.map(\.displayName), ["Priya"])

        await viewModel.refresh(known: [createdID])
        XCTAssertEqual(viewModel.people.map(\.displayName), ["Priya"])
    }

    func testDeleteRemovesFromList() async throws {
        let client = FakeVaultClient()
        let tickets = MockTicketProvider()
        let viewModel = ProfileListViewModel(client: client, tickets: tickets)

        let created = await viewModel.createProfile(kind: .organization, displayName: "Acme LLC")
        let createdID = try XCTUnwrap(created?.id)

        await viewModel.deleteProfile(createdID)
        XCTAssertTrue(viewModel.people.isEmpty)
    }

    func testLockedVaultSurfacesTypedErrorNotCrash() async {
        let client = FakeVaultClient()
        await client.setLockState(.locked)
        let tickets = MockTicketProvider()
        let viewModel = ProfileListViewModel(client: client, tickets: tickets)

        let created = await viewModel.createProfile(kind: .person, displayName: "Sam")
        XCTAssertNil(created)
        XCTAssertEqual(viewModel.lastError, .vaultLocked)
    }
}
