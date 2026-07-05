import Foundation
import CryptoKit

public enum MasterKeyError: Error, Sendable, Equatable {
    /// No master key has been generated yet — first-run state, distinct
    /// from `VaultError.vaultLocked` (CLAUDE.md §15: "vault-locked is a
    /// normal state") since this one means there is nothing to unlock at all.
    case notProvisioned
    case invalidRecoveryCode
    case sealFailed
}

/// Owns the vault master key's entire lifecycle: generation, SE-wrapped
/// storage, recovery-code-wrapped storage, unlock (either path), and
/// whole-vault crypto-shred (destroying every wrapped copy).
///
/// Deliberately holds no long-lived plaintext key material itself — it
/// hands back a `SymmetricKey` per call and the caller (`VaultLockController`)
/// is responsible for the mlock'd resident copy and its zeroization.
public actor MasterKeyManager {
    private let keychain: KeychainStore
    private let seBox: KeyWrappingProvider
    private let masterKeyAccount: String
    private let recoveryWrappedAccount: String

    public init(
        keychain: KeychainStore,
        seBox: KeyWrappingProvider,
        masterKeyAccount: String = "vaultform.vault.masterkey.se-wrapped",
        recoveryWrappedAccount: String = "vaultform.vault.masterkey.recovery-wrapped"
    ) {
        self.keychain = keychain
        self.seBox = seBox
        self.masterKeyAccount = masterKeyAccount
        self.recoveryWrappedAccount = recoveryWrappedAccount
    }

    public func isProvisioned() throws -> Bool {
        try keychain.get(account: masterKeyAccount) != nil
    }

    /// Generates a new 256-bit master key, wraps it under the Secure
    /// Enclave key (primary unlock path) and, separately, under a freshly
    /// generated recovery code (fallback path — ARCHITECTURE.md §6.2).
    /// Returns the recovery code for one-time display; this type never
    /// persists the plaintext code itself, only its wrapped effect.
    @discardableResult
    public func provision() throws -> RecoveryCode {
        let masterKey = SymmetricKey(size: .bits256)
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }

        let seWrapped = try seBox.wrap(masterKeyData)
        try keychain.set(seWrapped, account: masterKeyAccount)

        let recoveryCode = RecoveryCode.generate()
        let recoveryWrapped = try Self.seal(masterKeyData, using: recoveryCode.deriveWrappingKey())
        try keychain.set(recoveryWrapped, account: recoveryWrappedAccount)

        return recoveryCode
    }

    /// Primary unlock path: Secure Enclave unwrap (the OS gates this with a
    /// biometric/password prompt via the key's own access control).
    public func unlock() throws -> SymmetricKey {
        guard let wrapped = try keychain.get(account: masterKeyAccount) else {
            throw MasterKeyError.notProvisioned
        }
        let plaintext = try seBox.unwrap(wrapped)
        return SymmetricKey(data: plaintext)
    }

    /// Recovery path: survives an SE/biometry reset because it never
    /// touches the SE key at all.
    public func unlock(recoveryCode: RecoveryCode) throws -> SymmetricKey {
        guard let wrapped = try keychain.get(account: recoveryWrappedAccount) else {
            throw MasterKeyError.notProvisioned
        }
        do {
            let plaintext = try Self.open(wrapped, using: recoveryCode.deriveWrappingKey())
            return SymmetricKey(data: plaintext)
        } catch {
            throw MasterKeyError.invalidRecoveryCode
        }
    }

    /// Whole-vault crypto-shred (ARCHITECTURE.md §6.2): destroy every
    /// wrapped copy of the master key, SE-side and recovery-side. With no
    /// copy of the master key recoverable, the DB, attachments, and backups
    /// become permanently unreadable ciphertext — this is what makes
    /// crypto-shred instant regardless of data volume (PRD FR-2.6).
    public func shredMasterKey() throws {
        try keychain.delete(account: masterKeyAccount)
        try keychain.delete(account: recoveryWrappedAccount)
        try seBox.destroy()
    }

    private static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw MasterKeyError.sealFailed
        }
        return combined
    }

    private static func open(_ combined: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}
