import XCTest
import VaultAPI
@testable import VaultStore

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
}
