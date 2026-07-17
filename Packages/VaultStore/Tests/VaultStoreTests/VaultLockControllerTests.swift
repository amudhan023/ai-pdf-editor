import XCTest
import VaultAPI
import PolicyKit
import Platform
@testable import VaultStore

/// Wraps a real `KeyWrappingProvider` with an artificial delay on `unwrap`,
/// so tests can observe the transient `.unlocking` phase deterministically
/// instead of racing a same-actor-hop unlock to completion.
private struct SlowKeyWrappingProvider: KeyWrappingProvider {
    let inner: MockKeyWrappingProvider
    let delay: TimeInterval

    func wrap(_ plaintext: Data) throws -> Data { try inner.wrap(plaintext) }

    func unwrap(_ ciphertext: Data) throws -> Data {
        Thread.sleep(forTimeInterval: delay)
        return try inner.unwrap(ciphertext)
    }

    func destroy() throws { try inner.destroy() }
}

private struct FakeLocalAuthenticator: LocalAuthenticating {
    let result: Result<Void, LocalAuthenticationError>

    func authenticate(reason: String) async throws {
        switch result {
        case .success: return
        case .failure(let error): throw error
        }
    }
}

final class VaultLockControllerTests: XCTestCase {
    private func controller(name: String = #function) -> VaultLockController {
        let suffix = UUID().uuidString
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(name).\(suffix)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        return VaultLockController(masterKeyManager: manager)
    }

    func testKeysUnavailableBeforeUnlock() async throws {
        let controller = controller()
        let state = await controller.lockState
        XCTAssertEqual(state, .locked)
        do {
            _ = try await controller.databaseKey()
            XCTFail("databaseKey() before unlock must throw vaultLocked")
        } catch let error as VaultError {
            XCTAssertEqual(error, .vaultLocked)
        }
    }

    func testDerivedKeyDomainsAreDistinct() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        let controller = VaultLockController(masterKeyManager: manager)
        _ = try await manager.provision()
        try await controller.unlock()

        let dbKey = try await controller.databaseKey()
        let attachmentsKey = try await controller.attachmentsRootKey()
        let backupKey = try await controller.backupKey()

        let dbData = dbKey.withUnsafeBytes { Data($0) }
        let attachmentsData = attachmentsKey.withUnsafeBytes { Data($0) }
        let backupData = backupKey.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(dbData, attachmentsData)
        XCTAssertNotEqual(dbData, backupData)
        XCTAssertNotEqual(attachmentsData, backupData)
    }

    func testLockZeroizesAndSubsequentAccessThrows() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        let controller = VaultLockController(masterKeyManager: manager)
        _ = try await manager.provision()
        try await controller.unlock()
        _ = try await controller.databaseKey()

        await controller.lock()
        let state = await controller.lockState
        XCTAssertEqual(state, .locked)
        do {
            _ = try await controller.databaseKey()
            XCTFail("databaseKey() after lock() must throw vaultLocked")
        } catch let error as VaultError {
            XCTAssertEqual(error, .vaultLocked)
        }
    }

    func testStateMachineTransitionsThroughUnlockingPhase() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let mock = MockKeyWrappingProvider()
        let manager = MasterKeyManager(
            keychain: keychain, seBox: SlowKeyWrappingProvider(inner: mock, delay: 0.3),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)
        let initialPhase = await controller.lockPhase
        XCTAssertEqual(initialPhase, .locked)

        let unlockTask = Task { try await controller.unlock() }
        try await Task.sleep(nanoseconds: 100_000_000)
        let phaseWhileUnlocking = await controller.lockPhase
        XCTAssertEqual(phaseWhileUnlocking, .unlocking)
        let stateWhileUnlocking = await controller.lockState
        XCTAssertEqual(stateWhileUnlocking, .locked, "unlocking must still read as locked to VaultClient consumers")

        try await unlockTask.value
        let phaseAfterUnlock = await controller.lockPhase
        XCTAssertEqual(phaseAfterUnlock, .unlocked)

        await controller.lock()
        let phaseAfterLock = await controller.lockPhase
        XCTAssertEqual(phaseAfterLock, .locked)
    }

    func testLockAndUnlockEmitDomainEvents() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)

        let collector: Task<[VaultLockEvent], Never> = Task {
            var collected: [VaultLockEvent] = []
            for await event in controller.events {
                collected.append(event)
                if collected.count == 2 { break }
            }
            return collected
        }

        try await controller.unlock()
        await controller.lock(reason: .idleTimeout)
        let collected = await collector.value

        XCTAssertEqual(collected.count, 2)
        guard case .didUnlock = collected[0] else { return XCTFail("expected didUnlock first") }
        guard case .didLock(let reason, _) = collected[1] else { return XCTFail("expected didLock second") }
        XCTAssertEqual(reason, .idleTimeout)
    }

    func testAuthFreshnessIsSetOnUnlockAndClearedOnLock() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)

        let freshnessBeforeUnlock = await controller.authFreshness()
        XCTAssertNil(freshnessBeforeUnlock)
        try await controller.unlock()
        let freshnessAfterUnlock = await controller.authFreshness()
        let freshness = try XCTUnwrap(freshnessAfterUnlock)
        XCTAssertTrue(freshness.isFresh(at: Date(), within: 60))

        await controller.lock()
        let freshnessAfterLock = await controller.authFreshness()
        XCTAssertNil(freshnessAfterLock)
    }

    func testReauthenticateRefreshesFreshnessWithoutUnwrappingKeys() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)

        do {
            try await controller.reauthenticate(using: FakeLocalAuthenticator(result: .success(())), reason: "test")
            XCTFail("reauthenticate before unlock must throw vaultLocked")
        } catch let error as VaultError {
            XCTAssertEqual(error, .vaultLocked)
        }

        try await controller.unlock()
        let freshnessAfterUnlock = await controller.authFreshness()
        let before = try XCTUnwrap(freshnessAfterUnlock)
        try await Task.sleep(nanoseconds: 50_000_000)
        try await controller.reauthenticate(using: FakeLocalAuthenticator(result: .success(())), reason: "test")
        let freshnessAfterReauth = await controller.authFreshness()
        let after = try XCTUnwrap(freshnessAfterReauth)
        XCTAssertGreaterThan(after.lastAuthenticatedAt, before.lastAuthenticatedAt)

        do {
            try await controller.reauthenticate(using: FakeLocalAuthenticator(result: .failure(.userCancelled)), reason: "test")
            XCTFail("a failing authenticator must propagate its error")
        } catch let error as LocalAuthenticationError {
            XCTAssertEqual(error, .userCancelled)
        }
    }

    /// Deterministic via the injected `IdleSleeper` (P1-20): the controller's
    /// idle deadline only "fires" when this test releases the gated sleep, so
    /// no wall-clock margin exists to race against. The previous version used
    /// real `Task.sleep`s with ~50ms of scheduling margin and flaked on
    /// loaded CI runners.
    func testIdleTimeoutAutoLocksAndActivityDefersIt() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let sleeperGate = SleeperGate()
        let controller = VaultLockController(masterKeyManager: manager) { _ in
            try await sleeperGate.sleep()
        }

        try await controller.unlock()
        await controller.setIdleTimeout(0.2)
        try await sleeperGate.waitForSleepCount(1) // setIdleTimeout armed the monitor

        // Activity must cancel the armed deadline and arm a fresh one.
        await controller.noteActivity()
        try await sleeperGate.waitForSleepCount(2)
        let phaseAfterActivity = await controller.lockPhase
        XCTAssertEqual(phaseAfterActivity, .unlocked, "activity inside the window must defer the auto-lock")

        // Release the (only) live deadline: the fresh monitor's sleep returns
        // as if the timeout elapsed; the cancelled ones were resumed by
        // cancellation and must not lock.
        await sleeperGate.releaseLatest()
        for _ in 0..<200 {
            if await controller.lockPhase == .locked { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let phaseAfterIdle = await controller.lockPhase
        XCTAssertEqual(phaseAfterIdle, .locked, "idle past the timeout with no activity must auto-lock")
    }

    /// Boundary case the wall-clock version couldn't express: activity that
    /// lands after the deadline has already fired must not "revive" the
    /// vault — the lock stands, and the late activity arms nothing (the
    /// monitor only runs while unlocked).
    func testActivityAfterTheDeadlineFiredDoesNotUnlock() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let sleeperGate = SleeperGate()
        let controller = VaultLockController(masterKeyManager: manager) { _ in
            try await sleeperGate.sleep()
        }

        try await controller.unlock()
        await controller.setIdleTimeout(0.2)
        try await sleeperGate.waitForSleepCount(1)

        await sleeperGate.releaseLatest()
        for _ in 0..<200 {
            if await controller.lockPhase == .locked { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        await controller.noteActivity()
        let phase = await controller.lockPhase
        XCTAssertEqual(phase, .locked, "late activity must not revive a vault the deadline already locked")
        let sleeps = await sleeperGate.sleepCount
        XCTAssertEqual(sleeps, 1, "noteActivity while locked must not arm a new idle monitor")
    }

    func testRecoveryCodeUnlocksAfterSimulatedBiometryLoss() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let seBox = MockKeyWrappingProvider()
        let manager = MasterKeyManager(
            keychain: keychain, seBox: seBox,
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        let recoveryCode = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)

        // Simulates a Secure Enclave/biometry reset: the SE-side wrapping
        // key is destroyed (regenerated), so the SE-wrapped master key copy
        // in Keychain can no longer be unwrapped — but the recovery code's
        // wrapping key is independent (HKDF over the code itself).
        try seBox.destroy()

        do {
            try await controller.unlock()
            XCTFail("SE unlock after simulated biometry loss must fail")
        } catch {
            let phase = await controller.lockPhase
            XCTAssertEqual(phase, .locked)
        }

        try await controller.unlock(recoveryCode: recoveryCode)
        let phase = await controller.lockPhase
        XCTAssertEqual(phase, .unlocked)
        _ = try await controller.databaseKey()
    }

    /// Property: for every freshness window and every elapsed time since
    /// unlock, `PolicyRules.decide` requires re-auth for a Sensitive read
    /// exactly when the controller's own `authFreshness()` is stale — this
    /// is the seam the task's "auth-freshness feeds PolicyKit's
    /// `requireReauth` rule" requirement rests on, exercised end-to-end
    /// rather than by asserting on `AuthFreshness` in isolation.
    func testAuthFreshnessDrivesPolicyRequireReauthAcrossElapsedTimes() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let controller = VaultLockController(masterKeyManager: manager)
        try await controller.unlock()
        let currentFreshness = await controller.authFreshness()
        let freshness = try XCTUnwrap(currentFreshness)

        for (window, elapsed, expectReauth) in [
            (300.0, 60.0, false),
            (300.0, 600.0, true),
            (60.0, 30.0, false),
            (60.0, 90.0, true)
        ] {
            let now = freshness.lastAuthenticatedAt.addingTimeInterval(elapsed)
            let request = PolicyRequest(
                operation: .read, sensitivity: .sensitive, authFreshness: freshness, sessionMode: .normal
            )
            let decision = PolicyRules.decide(request, now: now, authFreshnessWindow: window)
            XCTAssertEqual(decision == .requireReauth, expectReauth, "window=\(window) elapsed=\(elapsed)")
        }
    }
}

/// Test-local gate standing in for `VaultLockController.IdleSleeper`: each
/// `sleep()` suspends until the test releases it (deadline "fires") or the
/// surrounding monitor task is cancelled (activity deferred it) — no wall
/// clock anywhere, which is the whole point (P1-20).
private actor SleeperGate {
    struct TimedOutWaitingForSleep: Error {}

    private var continuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var cancelledIDs: Set<Int> = []
    private(set) var sleepCount = 0

    func sleep() async throws {
        let id = sleepCount
        sleepCount += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if cancelledIDs.contains(id) {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuations[id] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    private func cancel(id: Int) {
        cancelledIDs.insert(id)
        continuations.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    /// Fires the newest armed deadline, as if its interval elapsed.
    func releaseLatest() {
        guard let latest = continuations.keys.max() else { return }
        continuations.removeValue(forKey: latest)?.resume()
    }

    /// The monitor arms asynchronously after `setIdleTimeout`/`noteActivity`
    /// return; this waits (bounded) for the Nth `sleep()` to be reached.
    func waitForSleepCount(_ count: Int) async throws {
        for _ in 0..<400 {
            if sleepCount >= count { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        throw TimedOutWaitingForSleep()
    }
}
