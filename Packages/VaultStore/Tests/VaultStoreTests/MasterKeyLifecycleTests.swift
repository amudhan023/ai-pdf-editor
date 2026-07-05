import XCTest
@testable import VaultStore

/// Key lifecycle against `MockKeyWrappingProvider` (real Secure Enclave
/// key generation isn't reachable in this sandbox — see that mock's doc
/// comment). Real Keychain calls run for real; confirmed working here.
final class MasterKeyLifecycleTests: XCTestCase {
    private func manager(name: String = #function) -> MasterKeyManager {
        let suffix = UUID().uuidString
        let keychain = KeychainStore(service: "com.vaultform.vault.tests.\(name).\(suffix)")
        return MasterKeyManager(
            keychain: keychain, seBox: MockKeyWrappingProvider(),
            masterKeyAccount: "masterkey.se-wrapped", recoveryWrappedAccount: "masterkey.recovery-wrapped"
        )
    }

    func testProvisionThenUnlockRecoversTheSameKey() async throws {
        let manager = manager()
        let recoveryCode = try await manager.provision()
        let isProvisioned = try await manager.isProvisioned()
        XCTAssertTrue(isProvisioned)

        let unlocked = try await manager.unlock()
        let recoveryUnlocked = try await manager.unlock(recoveryCode: recoveryCode)
        XCTAssertEqual(unlocked.withUnsafeBytes { Data($0) }, recoveryUnlocked.withUnsafeBytes { Data($0) })
    }

    func testUnlockBeforeProvisionThrowsNotProvisioned() async {
        let manager = manager()
        do {
            _ = try await manager.unlock()
            XCTFail("unlock before provision must throw")
        } catch {
            XCTAssertEqual(error as? MasterKeyError, .notProvisioned)
        }
    }

    func testWrongRecoveryCodeIsRejected() async throws {
        let manager = manager()
        _ = try await manager.provision()
        let wrongCode = RecoveryCode(plaintext: "WRONG-CODE-DOES-NOT-MATCH-0000")
        do {
            _ = try await manager.unlock(recoveryCode: wrongCode)
            XCTFail("a recovery code that doesn't match the provisioned one must be rejected")
        } catch {
            XCTAssertEqual(error as? MasterKeyError, .invalidRecoveryCode)
        }
    }

    /// Whole-vault crypto-shred: after destroying every wrapped copy,
    /// neither unlock path can ever open the vault again — the
    /// "attempted-open" verification this task's Acceptance Criteria asks for.
    func testShredMasterKeyMakesBothUnlockPathsPermanentlyFail() async throws {
        let manager = manager()
        let recoveryCode = try await manager.provision()
        try await manager.shredMasterKey()

        let isProvisioned = try await manager.isProvisioned()
        XCTAssertFalse(isProvisioned)

        do {
            _ = try await manager.unlock()
            XCTFail("unlock after crypto-shred must throw")
        } catch {
            XCTAssertEqual(error as? MasterKeyError, .notProvisioned)
        }
        do {
            _ = try await manager.unlock(recoveryCode: recoveryCode)
            XCTFail("recovery unlock after crypto-shred must throw")
        } catch {
            XCTAssertEqual(error as? MasterKeyError, .notProvisioned)
        }
    }
}
