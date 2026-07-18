import XCTest
@testable import Vaultform

final class WindowStateStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempFiles: [URL] = []

    override func setUp() {
        super.setUp()
        suiteName = "WindowStateStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        for file in tempFiles {
            try? FileManager.default.removeItem(at: file)
        }
        super.tearDown()
    }

    /// See `RecentDocumentsStoreTests`' identical helper for why this
    /// returns the bookmark-resolved URL rather than the raw one.
    private func makeTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        tempFiles.append(url)
        guard let bookmark = SecurityScopedBookmark.make(for: url), let resolved = SecurityScopedBookmark.resolve(bookmark) else {
            return url
        }
        return resolved
    }

    func testSaveThenRestoreRoundTripsURLAndFrame() {
        let store = WindowStateStore(defaults: defaults)
        let url = makeTempFile()
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)

        store.save([RestorableWindow(url: url, frame: frame)])
        let restored = store.restore()

        XCTAssertEqual(restored, [RestorableWindow(url: url, frame: frame)])
    }

    func testSaveOverwritesThePreviousSet() {
        let store = WindowStateStore(defaults: defaults)
        let stale = makeTempFile()
        store.save([RestorableWindow(url: stale, frame: .zero)])

        store.save([])

        XCTAssertTrue(store.restore().isEmpty)
    }

    func testClearRemovesSavedState() {
        let store = WindowStateStore(defaults: defaults)
        store.save([RestorableWindow(url: makeTempFile(), frame: .zero)])

        store.clear()

        XCTAssertTrue(store.restore().isEmpty)
    }

    func testDeletedFileIsDroppedOnRestore() {
        let store = WindowStateStore(defaults: defaults)
        let kept = makeTempFile()
        let deleted = makeTempFile()
        store.save([
            RestorableWindow(url: kept, frame: .zero),
            RestorableWindow(url: deleted, frame: .zero)
        ])
        try? FileManager.default.removeItem(at: deleted)
        tempFiles.removeAll { $0 == deleted }

        XCTAssertEqual(store.restore().map(\.url), [kept])
    }
}
