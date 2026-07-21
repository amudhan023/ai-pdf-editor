import Foundation
import VaultAPI

/// Lock-screen state machine: observes `VaultClient.lockState()`, drives the
/// unlock/re-auth prompt, runs an idle auto-lock timer, and gates the
/// recovery-code one-time reveal. UI-facing; the actual crypto/biometry is
/// behind `VaultUnlocking`/`RecoveryCodeProviding` (this package can't reach
/// `VaultStore`/`Platform`, see `Support/VaultUnlocking.swift`).
@MainActor
public final class VaultUnlockViewModel: ObservableObject {
    @Published public private(set) var lockState: VaultLockState = .locked
    @Published public private(set) var unlockErrorMessage: String?
    @Published public private(set) var recoveryCode: String?

    private let client: any VaultClient
    private let unlocker: any VaultUnlocking
    private let recoveryCodeProvider: any RecoveryCodeProviding
    private let idleTimeout: TimeInterval
    private var idleTask: Task<Void, Never>?

    public init(
        client: any VaultClient,
        unlocker: any VaultUnlocking,
        recoveryCodeProvider: any RecoveryCodeProviding,
        idleTimeout: TimeInterval = 5 * 60
    ) {
        self.client = client
        self.unlocker = unlocker
        self.recoveryCodeProvider = recoveryCodeProvider
        self.idleTimeout = idleTimeout
    }

    public func refreshLockState() async {
        lockState = await client.lockState()
    }

    public func unlock() async {
        unlockErrorMessage = nil
        do {
            try await unlocker.unlock()
            await refreshLockState()
            noteActivity()
        } catch {
            unlockErrorMessage = "\(error)"
        }
    }

    public func lock() async {
        idleTask?.cancel()
        await unlocker.lock()
        await refreshLockState()
    }

    /// Call on any user interaction with the vault window — resets the
    /// idle-auto-lock countdown. No-op while already locked.
    public func noteActivity() {
        idleTask?.cancel()
        guard lockState == .unlocked else { return }
        idleTask = Task { [weak self, idleTimeout] in
            try? await Task.sleep(nanoseconds: UInt64(idleTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.lock()
        }
    }

    /// Show-once recovery-code ceremony. `recoveryCode` stays populated in
    /// UI state after reveal (the user needs to keep reading/copying it),
    /// but a second call to this method always fails — the provider itself
    /// enforces one-time disclosure, this isn't just a UI-side flag.
    public func revealRecoveryCodeOnce() async {
        do {
            recoveryCode = try await recoveryCodeProvider.revealOnce()
        } catch {
            unlockErrorMessage = "\(error)"
        }
    }

    public func dismissRecoveryCode() {
        recoveryCode = nil
    }
}
