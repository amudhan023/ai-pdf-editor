import Foundation
import CryptoKit
import VaultAPI

/// Orchestrates unlock/lock against a `MasterKeyManager` and holds the
/// resulting master key plus its three derived keys (DB/attachments/backup)
/// as `LockedBytes` for as long as the vault is unlocked. `lock()` zeroizes
/// all four immediately — nothing here survives a lock/idle-timeout
/// (ARCHITECTURE.md §6.2).
public actor VaultLockController {
    private let masterKeyManager: MasterKeyManager
    private var unlocked: UnlockedKeys?

    private struct UnlockedKeys {
        let masterKey: LockedBytes
        let databaseKey: LockedBytes
        let attachmentsRootKey: LockedBytes
        let backupKey: LockedBytes
    }

    public init(masterKeyManager: MasterKeyManager) {
        self.masterKeyManager = masterKeyManager
    }

    public var lockState: VaultLockState {
        unlocked == nil ? .locked : .unlocked
    }

    /// Primary unlock path (Secure Enclave). Idempotent while already unlocked.
    public func unlock() async throws {
        guard unlocked == nil else { return }
        let masterKey = try await masterKeyManager.unlock()
        setUnlocked(masterKey: masterKey)
    }

    /// Recovery-code unlock path — used when the SE key/biometry enrollment
    /// is unavailable (ARCHITECTURE.md §6.2).
    public func unlock(recoveryCode: RecoveryCode) async throws {
        guard unlocked == nil else { return }
        let masterKey = try await masterKeyManager.unlock(recoveryCode: recoveryCode)
        setUnlocked(masterKey: masterKey)
    }

    public func lock() {
        unlocked?.masterKey.zeroize()
        unlocked?.databaseKey.zeroize()
        unlocked?.attachmentsRootKey.zeroize()
        unlocked?.backupKey.zeroize()
        unlocked = nil
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
    }
}
