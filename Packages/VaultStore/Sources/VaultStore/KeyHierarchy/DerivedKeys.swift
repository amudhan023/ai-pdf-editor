import Foundation
import CryptoKit

/// Domain-separated HKDF-SHA256 derivation from the vault master key
/// (ARCHITECTURE.md §6.2: "MK -> DB Key / Attachment Keys / Backup Key").
/// One master key, three independent-looking derived keys — compromising
/// one derived key's use site doesn't hand an attacker the others, and
/// rotating a derived key's *domain* (e.g. a future key-per-sensitivity-tier
/// upgrade, per ARCHITECTURE.md §8.2) needs no schema change, just a new
/// `info` string.
public enum VaultKeyDomain: String, Sendable {
    case database = "vaultform.key.database.v1"
    case attachmentsRoot = "vaultform.key.attachments-root.v1"
    case backups = "vaultform.key.backups.v1"
}

public enum DerivedKeys {
    public static func derive(_ domain: VaultKeyDomain, from masterKey: SymmetricKey) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            info: Data(domain.rawValue.utf8),
            outputByteCount: 32
        )
    }

    /// Per-attachment key, itself derived from the attachments-root key so
    /// no two files share a key and no per-file key needs its own Keychain
    /// entry — it's cheaply re-derivable from the root key plus the file's
    /// own id.
    public static func deriveAttachmentKey(attachmentID: UUID, rootKey: SymmetricKey) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            info: Data("vaultform.key.attachment.v1.\(attachmentID.uuidString)".utf8),
            outputByteCount: 32
        )
    }
}
