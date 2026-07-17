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

/// Test double for `VaultLockController.IdleWait`: every idle-deadline wait
/// parks on a continuation the test resolves explicitly with `fire(_:)`, so
/// "the timeout elapsed" is a test-controlled event rather than a race
/// between `Task.sleep` and the assertion (the P1-20 flake).
private actor IdleWaitGate {
    private var pending: [Int: CheckedContinuation<Void, Never>] = [:]
    private(set) var startedCount = 0

    func wait() async {
        let id = startedCount
        startedCount += 1
        await withCheckedContinuation { pending[id] = $0 }
    }

    /// Resumes wait number `id` (0-based, in start order) as if its deadline
    /// elapsed. Firing a wait whose monitor task was since cancelled is the
    /// point of several tests — the controller must ignore it.
    func fire(_ id: Int) {
        pending.removeValue(forKey: id)?.resume()
    }
}

final class VaultLockControllerTests: XCTestCase {
    /// The monitor task registers its wait asynchronously after
    /// `setIdleTimeout`/`noteActivity` return; yielding until it appears is
    /// scheduler-independent (the cap only bounds a genuinely hung failure).
    private func expectStartedWaits(_ count: Int, on gate: IdleWaitGate,
                                    file: StaticString = #filePath, line: UInt = #line) async {
        var attempts = 0
        while await gate.startedCount < count, attempts < 10_000 {
            await Task.yield()
            attempts += 1
        }
        let started = await gate.startedCount
        XCTAssertEqual(started, count, "expected \(count) idle waits to have started", file: file, line: line)
    }

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

    func testIdleTimeoutAutoLocksAndActivityDefersIt() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let gate = IdleWaitGate()
        let controller = VaultLockController(masterKeyManager: manager, idleWait: { _ in await gate.wait() })

        try await controller.unlock()
        await controller.setIdleTimeout(0.2)
        await expectStartedWaits(1, on: gate)

        // Activity supersedes the pending deadline (wait 0) with a fresh one
        // (wait 1). Firing the superseded deadline afterwards must not lock —
        // this is the "activity inside the window defers the auto-lock"
        // contract, without the wall-clock race the old sleeps had.
        await controller.noteActivity()
        await expectStartedWaits(2, on: gate)
        await gate.fire(0)
        for _ in 0..<100 { await Task.yield() }
        let phaseAfterActivity = await controller.lockPhase
        XCTAssertEqual(phaseAfterActivity, .unlocked, "activity inside the window must defer the auto-lock")

        await gate.fire(1)
        for await event in controller.events {
            guard case .didLock(let reason, _) = event else { continue }
            XCTAssertEqual(reason, .idleTimeout)
            break
        }
        let phaseAfterIdle = await controller.lockPhase
        XCTAssertEqual(phaseAfterIdle, .locked, "idle past the timeout with no activity must auto-lock")
    }

    /// Boundary case: the deadline elapses with no interim activity, and
    /// activity arrives only after the auto-lock has landed — it must not
    /// resurrect the monitor (no new wait while locked), and the vault stays
    /// locked.
    func testActivityAfterDeadlineHasFiredDoesNotDeferOrRestart() async throws {
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(#function).\(UUID().uuidString)")
        let manager = MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        _ = try await manager.provision()
        let gate = IdleWaitGate()
        let controller = VaultLockController(masterKeyManager: manager, idleWait: { _ in await gate.wait() })

        try await controller.unlock()
        await controller.setIdleTimeout(0.2)
        await expectStartedWaits(1, on: gate)

        await gate.fire(0)
        for await event in controller.events {
            if case .didLock(.idleTimeout, _) = event { break }
        }

        await controller.noteActivity()
        for _ in 0..<100 { await Task.yield() }
        let started = await gate.startedCount
        XCTAssertEqual(started, 1, "activity while locked must not start a new idle monitor")
        let phase = await controller.lockPhase
        XCTAssertEqual(phase, .locked)
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
