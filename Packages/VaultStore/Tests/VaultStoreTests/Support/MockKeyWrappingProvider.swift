import Foundation
import CryptoKit
@testable import VaultStore

/// Software-only `KeyWrappingProvider` test double. Real Secure Enclave key
/// generation needs an interactive Security Server session and real
/// hardware — unavailable here (see `SecureEnclaveKeyBox`'s doc comment) —
/// so key-lifecycle logic is exercised against this instead.
final class MockKeyWrappingProvider: KeyWrappingProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var wrappingKey = SymmetricKey(size: .bits256)

    func wrap(_ plaintext: Data) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let combined = try AES.GCM.seal(plaintext, using: wrappingKey).combined else {
            throw MockKeyWrappingProviderError.sealFailed
        }
        return combined
    }

    func unwrap(_ ciphertext: Data) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: wrappingKey)
    }

    func destroy() throws {
        lock.lock(); defer { lock.unlock() }
        wrappingKey = SymmetricKey(size: .bits256)
    }
}

enum MockKeyWrappingProviderError: Error {
    case sealFailed
}
