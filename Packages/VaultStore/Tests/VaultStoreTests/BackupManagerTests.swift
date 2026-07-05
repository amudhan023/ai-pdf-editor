import XCTest
import CryptoKit
@testable import VaultStore

final class BackupManagerTests: XCTestCase {
    private func makeManager(retentionCount: Int = 5) throws -> (BackupManager, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupManagerTests-\(UUID().uuidString)", isDirectory: true)
        let manager = try BackupManager(
            backupsDirectory: directory, backupKey: SymmetricKey(size: .bits256), retentionCount: retentionCount
        )
        return (manager, directory)
    }

    private func makeSourceFile(named name: String = "vault.sqlite", contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)")
        try contents.write(to: url)
        return url
    }

    func testSnapshotAndRestoreRoundTrip() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceContents = Data("sqlcipher-ciphertext-bytes".utf8)
        let source = try makeSourceFile(contents: sourceContents)
        defer { try? FileManager.default.removeItem(at: source) }

        let snapshot = try await manager.createSnapshot(of: source)
        let restored = FileManager.default.temporaryDirectory.appendingPathComponent("restored-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: restored) }
        try await manager.restore(from: snapshot, to: restored)

        XCTAssertEqual(try Data(contentsOf: restored), sourceContents)
    }

    func testSnapshotFileIsCiphertextNotPlaintext() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceContents = Data("sqlcipher-ciphertext-bytes".utf8)
        let source = try makeSourceFile(contents: sourceContents)
        defer { try? FileManager.default.removeItem(at: source) }

        let snapshot = try await manager.createSnapshot(of: source)
        let onDisk = try Data(contentsOf: snapshot)
        XCTAssertNil(onDisk.range(of: sourceContents))
    }

    func testRetentionPrunesOldestSnapshotsFirst() async throws {
        let (manager, directory) = try makeManager(retentionCount: 2)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try makeSourceFile(contents: Data("v".utf8))
        defer { try? FileManager.default.removeItem(at: source) }

        _ = try await manager.createSnapshot(of: source, now: Date(timeIntervalSince1970: 1))
        _ = try await manager.createSnapshot(of: source, now: Date(timeIntervalSince1970: 2))
        _ = try await manager.createSnapshot(of: source, now: Date(timeIntervalSince1970: 3))

        let remaining = try await manager.listSnapshots()
        XCTAssertEqual(remaining.count, 2)
    }

    func testSourceUnreadableThrows() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString)")

        do {
            _ = try await manager.createSnapshot(of: missing)
            XCTFail("snapshotting a nonexistent source file must throw")
        } catch let error as BackupError {
            XCTAssertEqual(error, .sourceUnreadable)
        }
    }
}
