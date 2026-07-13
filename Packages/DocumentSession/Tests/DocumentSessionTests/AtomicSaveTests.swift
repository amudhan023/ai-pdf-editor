import XCTest
import PDFEngineAPI
@testable import DocumentSession

/// Test-local mock (CLAUDE.md §5 `Mock*` naming): a `DocumentLifecycle`
/// whose `open` can be told to fail, so validation-failure behavior is
/// testable without needing a real corrupt-PDF parser. `FakePDFEngine`
/// (PDFEngineAPI) never fails `open` regardless of content, so it can't
/// exercise this path.
private actor MockLifecycle: DocumentLifecycle {
    var shouldFailOpen = false

    func open(url: URL) async throws -> DocumentHandle {
        if shouldFailOpen { throw PDFEngineError.corruptDocument(reason: "mock validation failure") }
        return DocumentHandle()
    }

    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws {}
    func close(_ document: DocumentHandle) async throws {}
}

final class AtomicSaveTests: XCTestCase {
    private struct Workspace {
        let dir: URL
        let original: URL
        let backups: URL
    }

    private func makeWorkspace() throws -> Workspace {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let backups = dir.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return Workspace(dir: dir, original: dir.appendingPathComponent("doc.pdf"), backups: backups)
    }

    private func writeTemp(_ contents: String, in dir: URL) throws -> URL {
        let temp = dir.appendingPathComponent("doc-\(UUID().uuidString).tmp")
        try Data(contents.utf8).write(to: temp)
        return temp
    }

    func testReplaceSwapsContentAtomicallyAndCreatesVersionedBackup() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("original".utf8).write(to: original)
        let temp = try writeTemp("new", in: dir)

        let saver = AtomicSaver(engine: MockLifecycle(), backupDirectory: backups)
        try await saver.replace(original: original, withTemp: temp)

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "new")
        let backupFiles = try FileManager.default.contentsOfDirectory(atPath: backups.path)
        XCTAssertEqual(backupFiles.count, 1)
        XCTAssertEqual(try String(contentsOf: backups.appendingPathComponent(backupFiles[0]), encoding: .utf8), "original")
    }

    /// The bug this regression-tests: the original `AtomicSaver` moved
    /// `original` to a single fixed `.backup` path, so a second save always
    /// threw "file exists." A document gets saved many times in its
    /// lifetime — this must never fail on save #2.
    func testConsecutiveSavesBothSucceedAndProduceDistinctBackups() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("v1".utf8).write(to: original)
        let saver = AtomicSaver(engine: MockLifecycle(), backupDirectory: backups)

        let tempA = try writeTemp("v2", in: dir)
        try await saver.replace(original: original, withTemp: tempA)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "v2")

        let tempB = try writeTemp("v3", in: dir)
        try await saver.replace(original: original, withTemp: tempB)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "v3")

        let backupFiles = try FileManager.default.contentsOfDirectory(atPath: backups.path)
        XCTAssertEqual(backupFiles.count, 2, "each save should add a versioned backup, not collide on a fixed name")
    }

    func testValidationFailureLeavesOriginalAndDoesNotWriteAnyBackup() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("untouched".utf8).write(to: original)
        let temp = try writeTemp("corrupt-payload", in: dir)

        let failingEngine = MockLifecycle()
        await failingEngine.setShouldFailOpen(true)
        let saver = AtomicSaver(engine: failingEngine, backupDirectory: backups)

        do {
            try await saver.replace(original: original, withTemp: temp)
            XCTFail("expected validationFailed")
        } catch let error as AtomicSaveError {
            guard case .validationFailed = error else {
                return XCTFail("expected .validationFailed, got \(error)")
            }
        }

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "untouched")
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.path), "temp is untouched by a failed validation")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backups.path), "no backup should be written on validation failure")
    }

    func testRetentionPrunesOldestBackupsBeyondCount() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("v0".utf8).write(to: original)
        let saver = AtomicSaver(engine: MockLifecycle(), backupDirectory: backups, retentionCount: 2)

        for index in 1...4 {
            let temp = try writeTemp("v\(index)", in: dir)
            try await saver.replace(original: original, withTemp: temp)
        }

        let backupFiles = try FileManager.default.contentsOfDirectory(atPath: backups.path)
        XCTAssertEqual(backupFiles.count, 2, "retentionCount should cap the number of kept versioned backups")
    }
}

private extension MockLifecycle {
    func setShouldFailOpen(_ value: Bool) {
        shouldFailOpen = value
    }
}

// MARK: - FileCoordinating injection

/// Records the URL it was asked to coordinate and either forwards to the
/// real body (default) or fails before calling it, so tests can prove
/// `AtomicSaver` (a) actually routes the swap through the coordinator and
/// (b) treats a coordination failure the same as a validation failure —
/// `original` untouched, no backup written.
private final class MockFileCoordinator: FileCoordinating, @unchecked Sendable {
    private(set) var coordinatedURLs: [URL] = []
    var shouldFailCoordination = false

    func coordinateReplace(of url: URL, using body: (URL) throws -> Void) throws {
        coordinatedURLs.append(url)
        if shouldFailCoordination {
            throw AtomicSaveError.ioError("mock coordination failure")
        }
        try body(url)
    }
}

extension AtomicSaveTests {
    func testReplaceRoutesThroughTheInjectedCoordinator() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("original".utf8).write(to: original)
        let temp = try writeTemp("new", in: dir)

        let coordinator = MockFileCoordinator()
        let saver = AtomicSaver(engine: MockLifecycle(), backupDirectory: backups, coordinator: coordinator)
        try await saver.replace(original: original, withTemp: temp)

        XCTAssertEqual(coordinator.coordinatedURLs, [original])
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "new")
    }

    func testCoordinationFailureLeavesOriginalAndDoesNotWriteAnyBackup() async throws {
        let workspace = try makeWorkspace()
        let (dir, original, backups) = (workspace.dir, workspace.original, workspace.backups)
        try Data("untouched".utf8).write(to: original)
        let temp = try writeTemp("new", in: dir)

        let coordinator = MockFileCoordinator()
        coordinator.shouldFailCoordination = true
        let saver = AtomicSaver(engine: MockLifecycle(), backupDirectory: backups, coordinator: coordinator)

        do {
            try await saver.replace(original: original, withTemp: temp)
            XCTFail("expected the coordination failure to surface")
        } catch let error as AtomicSaveError {
            guard case .ioError = error else {
                return XCTFail("expected .ioError, got \(error)")
            }
        }

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "untouched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backups.path), "no backup should be written when coordination fails")
    }
}
