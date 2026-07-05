import Foundation
import Security

/// Errors from a `KeychainStore` operation. Carries the raw `OSStatus` for
/// diagnostics — never any item content (CLAUDE.md §16: no vault values in
/// logs; an `OSStatus` int is not a value).
public enum KeychainError: Error, Sendable, Equatable {
    case unhandled(status: OSStatus)
    case unexpectedItemFormat
}

/// Opaque-blob storage over a single Keychain generic-password class,
/// scoped by `service` (so `VaultStore`'s items can't collide with another
/// package's) and keyed by `account`. This package never asks the Keychain
/// to encrypt/decrypt anything sensitive on our behalf — every blob stored
/// here already went through `KeyWrappingProvider`/AES-GCM first; the
/// Keychain's job is durable, per-user storage of opaque bytes, not the
/// cryptography itself.
public struct KeychainStore: Sendable {
    private let service: String
    private let accessibility: String

    public init(service: String = "com.vaultform.vault", accessibility: String = kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String) {
        self.service = service
        self.accessibility = accessibility
    }

    public func set(_ data: Data, account: String) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessibility,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    public func get(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
        guard let data = result as? Data else { throw KeychainError.unexpectedItemFormat }
        return data
    }

    @discardableResult
    public func delete(account: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
        return status == errSecSuccess
    }
}
