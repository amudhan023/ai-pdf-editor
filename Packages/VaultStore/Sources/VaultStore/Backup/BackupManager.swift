import Foundation
import CryptoKit

public enum BackupError: Error, Sendable, Equatable {
    case sealFailed
    case sourceUnreadable
}

/// Rolling encrypted local backups (ARCHITECTURE.md §8.1/§8.4: "backups:
/// local, encrypted, rolling"). Snapshots re-encrypt the already-SQLCipher-
/// encrypted DB file bytes under the separate backup-key domain — defense
/// in depth and an independent rotation lifecycle from the live DB key, not
/// a decryption step (the source bytes are ciphertext either way).
public actor BackupManager {
    private let backupsDirectory: URL
    private let backupKey: SymmetricKey
    private let retentionCount: Int

    public init(backupsDirectory: URL, backupKey: SymmetricKey, retentionCount: Int = 5) throws {
        self.backupsDirectory = backupsDirectory
        self.backupKey = backupKey
        self.retentionCount = retentionCount
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }

    /// Snapshots `sourceDBFile` (the caller is responsible for having
    /// checkpointed/closed any writer first so the bytes on disk are
    /// consistent). Prunes down to `retentionCount` newest snapshots after
    /// writing.
    @discardableResult
    public func createSnapshot(of sourceDBFile: URL, now: Date = Date()) throws -> URL {
        guard let sourceData = try? Data(contentsOf: sourceDBFile) else {
            throw BackupError.sourceUnreadable
        }
        guard let combined = try AES.GCM.seal(sourceData, using: backupKey).combined else {
            throw BackupError.sealFailed
        }
        let name = "vault-\(Self.timestampFormatter.string(from: now)).bak"
        let destination = backupsDirectory.appendingPathComponent(name)
        try combined.write(to: destination, options: .atomic)
        try pruneOldSnapshots()
        return destination
    }

    /// Decrypts a snapshot back into a usable SQLCipher DB file at
    /// `destination` (still SQLCipher ciphertext — the DB key is a separate
    /// unlock step, unrelated to this backup key).
    public func restore(from snapshot: URL, to destination: URL) throws {
        let combined = try Data(contentsOf: snapshot)
        let box = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(box, using: backupKey)
        try plaintext.write(to: destination, options: .atomic)
    }

    public func listSnapshots() throws -> [URL] {
        try orderedSnapshots()
    }

    private func pruneOldSnapshots() throws {
        let ordered = try orderedSnapshots()
        for stale in ordered.dropFirst(retentionCount) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private func orderedSnapshots() throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return try files.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
