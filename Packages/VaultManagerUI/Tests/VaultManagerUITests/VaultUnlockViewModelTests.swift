import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class VaultUnlockViewModelTests: XCTestCase {
    func testRefreshLockStateReflectsClient() async {
        let client = FakeVaultClient()
        await client.setLockState(.locked)
        let viewModel = VaultUnlockViewModel(client: client, unlocking: MockUnlocking())

        await viewModel.refreshLockState()
        XCTAssertEqual(viewModel.lockState, .locked)

        await client.setLockState(.unlocked)
        await viewModel.refreshLockState()
        XCTAssertEqual(viewModel.lockState, .unlocked)
    }

    func testBiometricFailureSurfacesTypedError() async {
        let client = FakeVaultClient()
        let unlocking = MockUnlocking()
        unlocking.biometricsResult = .failure(.biometricsFailed)
        let viewModel = VaultUnlockViewModel(client: client, unlocking: unlocking)

        await viewModel.unlockWithBiometrics()
        XCTAssertEqual(viewModel.lastError, .biometricsFailed)
    }

    func testSuccessfulUnlockClearsErrorAndRefreshesState() async {
        let client = FakeVaultClient()
        await client.setLockState(.locked)
        let unlocking = MockUnlocking()
        let viewModel = VaultUnlockViewModel(client: client, unlocking: unlocking)

        await client.setLockState(.unlocked)
        await viewModel.unlockWithBiometrics()

        XCTAssertNil(viewModel.lastError)
        XCTAssertEqual(viewModel.lockState, .unlocked)
    }

    func testLockNowInvokesCapabilityAndRefreshes() async {
        let client = FakeVaultClient()
        let unlocking = MockUnlocking()
        let viewModel = VaultUnlockViewModel(client: client, unlocking: unlocking)

        await viewModel.lockNow()
        XCTAssertEqual(unlocking.lockCallCount, 1)
    }
}
