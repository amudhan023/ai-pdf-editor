import Foundation
import CryptoKit

public struct AttachmentID: Sendable, Hashable, Codable {
    public let value: UUID
    public init(_ value: UUID = UUID()) { self.value = value }
}

public enum AttachmentStoreError: Error, Sendable, Equatable {
    case sealFailed
    case notFound(AttachmentID)
}

/// Per-file AES-256-GCM encrypted attachment store (ARCHITECTURE.md §8.1's
/// "attachments/... per-file AES-256-GCM encrypted originals"). Each file's
/// key is HKDF-derived from the attachments-root key plus its own id — no
/// two files share a key, and no per-file key needs its own Keychain entry.
public actor AttachmentStore {
    private let directory: URL
    private let rootKey: SymmetricKey

    public init(directory: URL, rootKey: SymmetricKey) throws {
        self.directory = directory
        self.rootKey = rootKey
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    public func store(_ plaintext: Data, id: AttachmentID = AttachmentID()) throws -> AttachmentID {
        let fileKey = DerivedKeys.deriveAttachmentKey(attachmentID: id.value, rootKey: rootKey)
        guard let combined = try AES.GCM.seal(plaintext, using: fileKey).combined else {
            throw AttachmentStoreError.sealFailed
        }
        try combined.write(to: url(for: id), options: .atomic)
        return id
    }

    public func load(_ id: AttachmentID) throws -> Data {
        guard let combined = try? Data(contentsOf: url(for: id)) else {
            throw AttachmentStoreError.notFound(id)
        }
        let fileKey = DerivedKeys.deriveAttachmentKey(attachmentID: id.value, rootKey: rootKey)
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: fileKey)
    }

    public func delete(_ id: AttachmentID) throws {
        try FileManager.default.removeItem(at: url(for: id))
    }

    private func url(for id: AttachmentID) -> URL {
        directory.appendingPathComponent(id.value.uuidString)
    }
}
