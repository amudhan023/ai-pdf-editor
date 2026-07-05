import XCTest
import CryptoKit
@testable import VaultStore

final class AttachmentStoreTests: XCTestCase {
    private func makeStore() throws -> (AttachmentStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AttachmentStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = try AttachmentStore(directory: directory, rootKey: SymmetricKey(size: .bits256))
        return (store, directory)
    }

    func testStoreAndLoadRoundTrip() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let plaintext = Data("passport-scan-bytes".utf8)

        let id = try await store.store(plaintext)
        let loaded = try await store.load(id)
        XCTAssertEqual(loaded, plaintext)
    }

    func testFileOnDiskIsCiphertextNotPlaintext() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let plaintext = Data("passport-scan-bytes".utf8)
        let id = try await store.store(plaintext)

        let onDisk = try Data(contentsOf: directory.appendingPathComponent(id.value.uuidString))
        XCTAssertNil(onDisk.range(of: plaintext), "attachment bytes on disk must never contain the plaintext")
    }

    func testTamperedCiphertextFailsToLoad() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try await store.store(Data("passport-scan-bytes".utf8))
        let path = directory.appendingPathComponent(id.value.uuidString)

        var bytes = try Data(contentsOf: path)
        bytes[bytes.count / 2] ^= 0xFF
        try bytes.write(to: path)

        do {
            _ = try await store.load(id)
            XCTFail("AES-GCM authentication must fail on tampered ciphertext")
        } catch {
            // AES.GCM.open throws CryptoKitError.authenticationFailure — any
            // throw here proves tamper-detection is working.
        }
    }

    func testLoadUnknownAttachmentThrowsNotFound() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missingID = AttachmentID()

        do {
            _ = try await store.load(missingID)
            XCTFail("loading a never-stored attachment must throw")
        } catch let error as AttachmentStoreError {
            XCTAssertEqual(error, .notFound(missingID))
        }
    }
}
