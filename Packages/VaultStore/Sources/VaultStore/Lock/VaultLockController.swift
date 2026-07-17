import Foundation
import CryptoKit
import VaultAPI
import PolicyKit
import Platform

/// The state-machine phase this controller tracks internally. Distinct from
/// `VaultAPI.VaultLockState` (frozen seam, locked/unlocked only): `unlocking`
/// is a transient phase real consumers of the frozen `VaultClient` protocol
/// don't need to observe (they see `.locked` throughout), but the task's
/// state-machine requirement — and this actor's own reentrancy safety, so a
/// second `unlock()` call arriving mid-unlock doesn't race the key derivation
/// — does.
enum VaultLockPhase: Sendable, Equatable {
    case locked
    case unlocking
    case unlocked
}

/// Orchestrates unlock/lock against a `MasterKeyManager` and holds the
/// resulting master key plus its three derived keys (DB/attachments/backup)
/// as `LockedBytes` for as long as the vault is unlocked. `lock()` zeroizes
/// all four immediately — nothing here survives a lock/idle-timeout
/// (ARCHITECTURE.md §6.2).
public actor VaultLockController {
    /// Seam for the idle monitor's deadline wait, injectable so tests can
    /// resolve deadlines deterministically instead of racing `Task.sleep`
    /// against the assertion (the P1-20 flake). Production always uses the
    /// `Task.sleep` default; the seam is internal on purpose.
    typealias IdleWait = @Sendable (_ timeout: TimeInterval) async throws -> Void

    private let masterKeyManager: MasterKeyManager
    private let idleWait: IdleWait
    private var unlocked: UnlockedKeys?
    private var phase: VaultLockPhase = .locked
    private var lastAuthenticatedAt: Date?
    private var idleTimeout: TimeInterval?
    private var idleMonitorTask: Task<Void, Never>?
    private let eventContinuation: AsyncStream<VaultLockEvent>.Continuation
    public nonisolated let events: AsyncStream<VaultLockEvent>

    private struct UnlockedKeys {
        let masterKey: LockedBytes
        let databaseKey: LockedBytes
        let attachmentsRootKey: LockedBytes
        let backupKey: LockedBytes
    }

    public init(masterKeyManager: MasterKeyManager) {
        self.init(masterKeyManager: masterKeyManager, idleWait: { timeout in
            try await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
        })
    }

    init(masterKeyManager: MasterKeyManager, idleWait: @escaping IdleWait) {
        self.masterKeyManager = masterKeyManager
        self.idleWait = idleWait
        (events, eventContinuation) = AsyncStream.makeStream(of: VaultLockEvent.self)
    }

    /// Frozen-seam-compatible projection: `VaultClient.lockState()` only
    /// distinguishes locked/unlocked, so `.unlocking` reads as `.locked` —
    /// no read/write path is available until the transition completes.
    public var lockState: VaultLockState {
        phase == .unlocked ? .unlocked : .locked
    }

    /// The internal three-phase state, for state-machine tests and callers
    /// that need to distinguish "mid-unlock" from "never started."
    var lockPhase: VaultLockPhase { phase }

    /// How long the vault may sit idle (no `noteActivity()` call) before
    /// auto-locking. `nil` (the default) disables idle auto-lock.
    public func setIdleTimeout(_ timeout: TimeInterval?) {
        idleTimeout = timeout
        restartIdleMonitor()
    }

    /// Call on any user-visible activity while unlocked to push back the
    /// idle-timeout deadline.
    public func noteActivity() {
        restartIdleMonitor()
    }

    /// Primary unlock path (Secure Enclave). Idempotent while already unlocked.
    public func unlock() async throws {
        guard phase == .locked else { return }
        phase = .unlocking
        do {
            let masterKey = try await masterKeyManager.unlock()
            setUnlocked(masterKey: masterKey)
        } catch {
            phase = .locked
            throw error
        }
    }

    /// Recovery-code unlock path — used when the SE key/biometry enrollment
    /// is unavailable (ARCHITECTURE.md §6.2).
    public func unlock(recoveryCode: RecoveryCode) async throws {
        guard phase == .locked else { return }
        phase = .unlocking
        do {
            let masterKey = try await masterKeyManager.unlock(recoveryCode: recoveryCode)
            setUnlocked(masterKey: masterKey)
        } catch {
            phase = .locked
            throw error
        }
    }

    /// Explicit re-auth (Touch ID/Apple Watch/password) that refreshes the
    /// auth-freshness signal PolicyKit's `requireReauth` rule reads, without
    /// unwrapping any key — for a vault that's already unlocked but whose
    /// last authentication has aged past a Sensitive-tier operation's
    /// freshness window.
    public func reauthenticate(using authenticator: LocalAuthenticating, reason: String) async throws {
        guard phase == .unlocked else { throw VaultError.vaultLocked }
        try await authenticator.authenticate(reason: reason)
        lastAuthenticatedAt = Date()
    }

    /// The auth-freshness signal for `PolicyRules.decide`'s `authFreshness`
    /// input. `nil` while locked — callers must not fabricate a freshness
    /// value for a vault that was never unlocked.
    public func authFreshness() -> AuthFreshness? {
        lastAuthenticatedAt.map(AuthFreshness.init(lastAuthenticatedAt:))
    }

    public func lock(reason: VaultLockReason = .manual) {
        guard phase != .locked else { return }
        unlocked?.masterKey.zeroize()
        unlocked?.databaseKey.zeroize()
        unlocked?.attachmentsRootKey.zeroize()
        unlocked?.backupKey.zeroize()
        unlocked = nil
        phase = .locked
        lastAuthenticatedAt = nil
        idleMonitorTask?.cancel()
        idleMonitorTask = nil
        eventContinuation.yield(.didLock(reason: reason, at: Date()))
    }

    func databaseKey() throws -> SymmetricKey {
        guard let unlocked else { throw VaultError.vaultLocked }
        return SymmetricKey(data: unlocked.databaseKey.data)
    }

    func attachmentsRootKey() throws -> SymmetricKey {
        guard let unlocked else { throw VaultError.vaultLocked }
        return SymmetricKey(data: unlocked.attachmentsRootKey.data)
    }

    func backupKey() throws -> SymmetricKey {
        guard let unlocked else { throw VaultError.vaultLocked }
        return SymmetricKey(data: unlocked.backupKey.data)
    }

    private func setUnlocked(masterKey: SymmetricKey) {
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        let databaseKey = DerivedKeys.derive(.database, from: masterKey)
        let attachmentsRootKey = DerivedKeys.derive(.attachmentsRoot, from: masterKey)
        let backupKey = DerivedKeys.derive(.backups, from: masterKey)
        unlocked = UnlockedKeys(
            masterKey: LockedBytes(masterKeyData),
            databaseKey: LockedBytes(databaseKey.withUnsafeBytes { Data($0) }),
            attachmentsRootKey: LockedBytes(attachmentsRootKey.withUnsafeBytes { Data($0) }),
            backupKey: LockedBytes(backupKey.withUnsafeBytes { Data($0) })
        )
        phase = .unlocked
        lastAuthenticatedAt = Date()
        eventContinuation.yield(.didUnlock(at: Date()))
        restartIdleMonitor()
    }

    /// Cancels any in-flight idle-deadline wait and, if unlocked with a
    /// timeout configured, starts a fresh one. An actor-hop `Task` rather
    /// than `DispatchQueue`/`Timer` per CLAUDE.md §4 ("no `DispatchQueue` in
    /// new code"); cancellation on every call is what makes repeated
    /// `noteActivity()` calls cheap rather than leaking a task per call.
    private func restartIdleMonitor() {
        idleMonitorTask?.cancel()
        idleMonitorTask = nil
        guard phase == .unlocked, let idleTimeout else { return }
        idleMonitorTask = Task { [weak self, idleWait] in
            try? await idleWait(idleTimeout)
            guard !Task.isCancelled, let self else { return }
            await self.lockDueToIdleTimeout()
        }
    }

    private func lockDueToIdleTimeout() {
        guard phase == .unlocked else { return }
        lock(reason: .idleTimeout)
    }
}
