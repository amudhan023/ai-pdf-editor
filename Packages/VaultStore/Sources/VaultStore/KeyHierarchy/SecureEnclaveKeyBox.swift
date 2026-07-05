import Foundation
import Security

/// Real `KeyWrappingProvider` backed by a non-exportable Secure Enclave EC
/// key (ARCHITECTURE.md §6.2's "SE key (non-exportable, biometry-bound
/// policy)"). Wrapping uses ECIES (cofactor X9.63 KDF w/ SHA256, AES-GCM
/// payload) against the SE key's public half; unwrapping calls
/// `SecKeyCreateDecryptedData` against the SE private key, which the OS
/// gates with a Touch ID/password prompt per the key's access control —
/// this type never talks to `LocalAuthentication` directly, the access
/// control on the key itself is what causes the system prompt.
///
/// **Not exercised end-to-end by this package's test suite**: generating an
/// SE key requires a real Secure Enclave and an interactive Security
/// Server session. Confirmed empirically in this environment —
/// `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave` fails with
/// `errSecInteractionNotAllowed` (-25308) in a headless sandbox — the same
/// class of environment gap as `tasks/escalations/E-002-no-xctest-without-xcode.md`.
/// Key-lifecycle logic is instead tested against a software test double of
/// `KeyWrappingProvider`; this type is reviewed for correct API usage but
/// wants real-hardware verification before first production unlock.
public struct SecureEnclaveKeyBox: KeyWrappingProvider {
    private let applicationTag: Data
    private let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorX963SHA256AESGCM

    public init(tag: String = "com.vaultform.vault.se-master-key") {
        self.applicationTag = Data(tag.utf8)
    }

    public func wrap(_ plaintext: Data) throws -> Data {
        let privateKey = try loadOrCreateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveKeyBoxError.noPublicKey
        }
        var error: Unmanaged<CFError>?
        guard let ciphertext = SecKeyCreateEncryptedData(publicKey, algorithm, plaintext as CFData, &error) else {
            throw SecureEnclaveKeyBoxError.cryptoFailed(error?.takeRetainedValue())
        }
        return ciphertext as Data
    }

    public func unwrap(_ ciphertext: Data) throws -> Data {
        let privateKey = try loadKey()
        var error: Unmanaged<CFError>?
        guard let plaintext = SecKeyCreateDecryptedData(privateKey, algorithm, ciphertext as CFData, &error) else {
            throw SecureEnclaveKeyBoxError.cryptoFailed(error?.takeRetainedValue())
        }
        return plaintext as Data
    }

    public func destroy() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureEnclaveKeyBoxError.keychainStatus(status)
        }
    }

    private func loadKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw SecureEnclaveKeyBoxError.notProvisioned }
        // swiftlint:disable:next force_cast
        return (result as! SecKey)
    }

    private func loadOrCreateKey() throws -> SecKey {
        if let existing = try? loadKey() { return existing }

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &accessControlError
        ) else {
            throw SecureEnclaveKeyBoxError.cryptoFailed(accessControlError?.takeRetainedValue())
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: applicationTag,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        var keyError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &keyError) else {
            throw SecureEnclaveKeyBoxError.cryptoFailed(keyError?.takeRetainedValue())
        }
        return privateKey
    }
}

public enum SecureEnclaveKeyBoxError: Error, CustomStringConvertible {
    case notProvisioned
    case noPublicKey
    case cryptoFailed(CFError?)
    case keychainStatus(OSStatus)

    public var description: String {
        switch self {
        case .notProvisioned: "no Secure Enclave key has been provisioned yet"
        case .noPublicKey: "could not derive a public key from the Secure Enclave private key"
        case .cryptoFailed(let error): "Secure Enclave operation failed: \(error.map(String.init(describing:)) ?? "unknown")"
        case .keychainStatus(let status): "Keychain operation failed: \(status)"
        }
    }
}
