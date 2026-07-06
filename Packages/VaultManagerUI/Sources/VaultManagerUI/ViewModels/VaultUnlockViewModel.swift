import Foundation
import VaultAPI

/// Drives the unlock screen and auto-lock behavior. `VaultClient.lockState()`
/// is poll-only (no subscription in the frozen `VaultAPI` protocol), so
/// callers re-check via `refreshLockState()` after any action that could
/// have changed it; the auto-lock timer is this view model's own state, not
/// something the vault client tracks.
@MainActor
public final class VaultUnlockViewModel: ObservableObject {
    public static let defaultAutoLockInterval: TimeInterval = 5 * 60

    @Published public private(set) var lockState: VaultLockState = .locked
    @Published public private(set) var lastError: VaultUnlockError?
    public var autoLockInterval: TimeInterval

    private let client: any VaultClient
    private let unlocking: any VaultUnlocking
    private var autoLockTask: Task<Void, Never>?

    public init(
        client: any VaultClient,
        unlocking: any VaultUnlocking,
        autoLockInterval: TimeInterval = defaultAutoLockInterval
    ) {
        self.client = client
        self.unlocking = unlocking
        self.autoLockInterval = autoLockInterval
    }

    public func refreshLockState() async {
        lockState = await client.lockState()
    }

    public func unlockWithBiometrics() async {
        do {
            try await unlocking.unlockWithBiometrics()
            lastError = nil
            await refreshLockState()
            resetAutoLockTimer()
        } catch let error as VaultUnlockError {
            lastError = error
        } catch {
            lastError = .biometricsFailed
        }
    }

    public func unlockWithRecoveryCode(_ code: String) async {
        do {
            try await unlocking.unlockWithRecoveryCode(code)
            lastError = nil
            await refreshLockState()
            resetAutoLockTimer()
        } catch let error as VaultUnlockError {
            lastError = error
        } catch {
            lastError = .invalidRecoveryCode
        }
    }

    public func lockNow() async {
        autoLockTask?.cancel()
        await unlocking.lock()
        await refreshLockState()
    }

    /// Call on any observed user activity while unlocked to push the
    /// auto-lock deadline back out.
    public func resetAutoLockTimer() {
        autoLockTask?.cancel()
        let interval = autoLockInterval
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.lockNow()
        }
    }
}
