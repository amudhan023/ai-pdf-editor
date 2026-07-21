import XCTest
import VaultAPI
@testable import VaultManagerUI

@MainActor
final class VaultUnlockViewModelTests: XCTestCase {
    private func makeViewModel(idleTimeout: TimeInterval = 300) async -> (VaultUnlockViewModel, FakeVaultClient) {
        let client = FakeVaultClient()
        await client.setLockState(.locked) // FakeVaultClient defaults to .unlocked; the UI's own baseline is locked
        let clock = InMemoryAuthFreshnessClock()
        let unlocker = FakeVaultUnlocker(client: client, authFreshnessClock: clock)
        let recovery = FakeRecoveryCodeProvider(code: "TEST-CODE")
        let viewModel = VaultUnlockViewModel(client: client, unlocker: unlocker, recoveryCodeProvider: recovery, idleTimeout: idleTimeout)
        return (viewModel, client)
    }

    func testStartsLocked() async {
        let (viewModel, _) = await makeViewModel()
        await viewModel.refreshLockState()
        XCTAssertEqual(viewModel.lockState, .locked)
    }

    func testUnlockTransitionsToUnlocked() async {
        let (viewModel, _) = await makeViewModel()
        await viewModel.unlock()
        XCTAssertEqual(viewModel.lockState, .unlocked)
        XCTAssertNil(viewModel.unlockErrorMessage)
    }

    func testLockTransitionsBackToLocked() async {
        let (viewModel, _) = await makeViewModel()
        await viewModel.unlock()
        await viewModel.lock()
        XCTAssertEqual(viewModel.lockState, .locked)
    }

    func testRevealRecoveryCodeOnceThenRefusesSecondReveal() async {
        let (viewModel, _) = await makeViewModel()
        await viewModel.revealRecoveryCodeOnce()
        XCTAssertEqual(viewModel.recoveryCode, "TEST-CODE")

        viewModel.dismissRecoveryCode()
        await viewModel.revealRecoveryCodeOnce()

        XCTAssertNil(viewModel.recoveryCode)
        XCTAssertNotNil(viewModel.unlockErrorMessage)
    }

    func testIdleTimeoutAutoLocks() async {
        let (viewModel, _) = await makeViewModel(idleTimeout: 0.05)
        await viewModel.unlock()
        XCTAssertEqual(viewModel.lockState, .unlocked)

        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.lockState, .locked)
    }

    func testActivityDefersAutoLock() async {
        let (viewModel, _) = await makeViewModel(idleTimeout: 0.15)
        await viewModel.unlock()

        try? await Task.sleep(nanoseconds: 80_000_000)
        viewModel.noteActivity() // resets the countdown before it fires
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.lockState, .unlocked)
    }
}
