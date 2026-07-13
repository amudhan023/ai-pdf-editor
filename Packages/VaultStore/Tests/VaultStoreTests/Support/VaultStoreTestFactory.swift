import Foundation
import Platform
@testable import VaultStore

/// Builds a fully-wired, throwaway vault (unique Keychain account suffix per
/// call so parallel test methods never collide) rooted at a temp directory
/// that's removed when the caller is done. Keychain itself works in this
/// sandbox (confirmed in the task Journal); only Secure Enclave key
/// generation doesn't, which is why `MockKeyWrappingProvider` stands in for
/// `SecureEnclaveKeyBox` here.
enum VaultStoreTestFactory {
    struct Harness {
        let dbURL: URL
        let directory: URL
        let masterKeyManager: MasterKeyManager
        let lockController: VaultLockController

        func makeStore(domainEventBus: DomainEventBus? = nil) -> SQLCipherVaultStore {
            SQLCipherVaultStore(dbURL: dbURL, lockController: lockController, domainEventBus: domainEventBus)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    static func makeHarness(name: String = #function) throws -> Harness {
        let suffix = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultStoreTests-\(name)-\(suffix)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(suffix)")
        let seBox = MockKeyWrappingProvider()
        let masterKeyManager = MasterKeyManager(
            keychain: keychain,
            seBox: seBox,
            masterKeyAccount: "masterkey.se-wrapped",
            recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
        let lockController = VaultLockController(masterKeyManager: masterKeyManager)

        return Harness(
            dbURL: directory.appendingPathComponent("vault.sqlite"),
            directory: directory,
            masterKeyManager: masterKeyManager,
            lockController: lockController
        )
    }
}
