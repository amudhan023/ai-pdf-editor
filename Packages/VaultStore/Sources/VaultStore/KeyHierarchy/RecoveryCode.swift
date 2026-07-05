import Foundation
import CryptoKit

/// A user-held recovery code that wraps a second copy of the vault master
/// key (ARCHITECTURE.md §6.2: "Recovery Code (user-held, printed once)
/// wraps MK copy — survives biometry reset"). Deliberately independent of
/// the Secure Enclave key: its wrapping key is derived from the code itself
/// via HKDF, so it keeps working even if the SE key/biometry enrollment is
/// reset — that independence is the entire point of having it.
///
/// `plaintext` exists only transiently, for the caller to hand to the
/// one-time-display UI (out of scope here per the task background) and
/// then discard; nothing in this package persists it.
public struct RecoveryCode: Sendable, Equatable {
    public let plaintext: String

    public init(plaintext: String) {
        self.plaintext = plaintext
    }

    /// 32 characters drawn from an unambiguous alphabet (no 0/O/1/I/L),
    /// grouped for readability — plenty of entropy (32 * log2(32) = 160
    /// bits) for a value the user copies down once and rarely types back.
    public static func generate() -> RecoveryCode {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        var raw = [Character]()
        raw.reserveCapacity(32)
        for _ in 0..<32 {
            raw.append(alphabet[Int.random(in: 0..<alphabet.count)])
        }
        let grouped = stride(from: 0, to: raw.count, by: 4)
            .map { String(raw[$0..<min($0 + 4, raw.count)]) }
            .joined(separator: "-")
        return RecoveryCode(plaintext: grouped)
    }

    /// Deterministic HKDF-SHA256 derivation, fixed salt/info so the same
    /// code always yields the same wrapping key (needed to unwrap a
    /// previously-wrapped master key copy).
    func deriveWrappingKey() -> SymmetricKey {
        let ikm = SymmetricKey(data: Data(plaintext.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: Data("vaultform.recovery-wrap.v1.salt".utf8),
            info: Data("vaultform.recovery-wrap.v1.info".utf8),
            outputByteCount: 32
        )
    }
}
