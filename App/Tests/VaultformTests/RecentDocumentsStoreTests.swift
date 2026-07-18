import XCTest
@testable import Vaultform

/// Bookmarks can only be created for files that exist on disk, so these
/// tests write real temp files rather than using bare `URL`s — and use a
/// dedicated `UserDefaults` suite, torn down after each test, per the
/// project's "never touch real `UserDefaults` from tests" rule
/// (`DocumentSession`'s `ScrollPosition.swift` doc comment).
final class RecentDocumentsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempFiles: [URL] = []

    override func setUp() {
        super.setUp()
        suiteName = "RecentDocumentsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        for file in tempFiles {
            try? FileManager.default.removeItem(at: file)
        }
        super.tearDown()
    }

    /// Returns the *bookmark-resolved* URL, not the raw one handed to
    /// `createFile` — `/var` is a symlink to `/private/var` on macOS, and
    /// bookmark resolution always returns the canonical path.
    /// `resolvingSymlinksInPath()` deliberately does not normalize this
    /// particular symlink (an Apple compatibility quirk with temp-dir
    /// paths), so round-tripping through a bookmark is the only way to get
    /// a URL that will string-compare equal to what `recentURLs()` returns.
    private func makeTempFile(named name: String = UUID().uuidString) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("pdf")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        tempFiles.append(url)
        guard let bookmark = SecurityScopedBookmark.make(for: url), let resolved = SecurityScopedBookmark.resolve(bookmark) else {
            return url
        }
        return resolved
    }

    func testRecordThenRecentURLsReturnsMostRecentFirst() {
        let store = RecentDocumentsStore(defaults: defaults)
        let first = makeTempFile()
        let second = makeTempFile()

        store.record(url: first)
        store.record(url: second)

        XCTAssertEqual(store.recentURLs().map(\.path), [second.path, first.path])
    }

    func testRecordingTheSameURLAgainMovesItToTheFront() {
        let store = RecentDocumentsStore(defaults: defaults)
        let first = makeTempFile()
        let second = makeTempFile()

        store.record(url: first)
        store.record(url: second)
        store.record(url: first)

        XCTAssertEqual(store.recentURLs().map(\.path), [first.path, second.path])
    }

    func testEntriesBeyondMaxAreDropped() {
        let store = RecentDocumentsStore(defaults: defaults, maxEntries: 2)
        let urls = (0..<3).map { _ in makeTempFile() }
        for url in urls {
            store.record(url: url)
        }

        XCTAssertEqual(store.recentURLs().map(\.path), [urls[2].path, urls[1].path])
    }

    func testDeletedFileIsDroppedFromRecents() {
        let store = RecentDocumentsStore(defaults: defaults)
        let kept = makeTempFile()
        let deleted = makeTempFile()
        store.record(url: kept)
        store.record(url: deleted)
        try? FileManager.default.removeItem(at: deleted)
        tempFiles.removeAll { $0 == deleted }

        XCTAssertEqual(store.recentURLs().map(\.path), [kept.path])
    }

    func testClearRemovesAllEntries() {
        let store = RecentDocumentsStore(defaults: defaults)
        store.record(url: makeTempFile())

        store.clear()

        XCTAssertTrue(store.recentURLs().isEmpty)
    }
}
