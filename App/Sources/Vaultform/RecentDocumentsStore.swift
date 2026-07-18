import Foundation

/// "Open Recent" history: most-recent-first, de-duplicated by path, capped
/// at `maxEntries`. `UserDefaults`-backed like `DocumentSession`'s
/// `UserDefaultsScrollPositionStore` (same "inject `UserDefaults`, tests use
/// a distinct suite, never touch the real one" pattern — see that package's
/// CLAUDE.md); no in-process fake exists because nothing outside this file
/// consumes the protocol shape.
final class RecentDocumentsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let maxEntries: Int
    private let lock = NSLock()
    private static let key = "com.vaultform.app.recentDocuments"

    init(defaults: UserDefaults = .standard, maxEntries: Int = 10) {
        self.defaults = defaults
        self.maxEntries = maxEntries
    }

    func record(url: URL) {
        guard let bookmark = SecurityScopedBookmark.make(for: url) else { return }
        lock.lock()
        defer { lock.unlock() }
        var entries = rawEntries()
        entries.removeAll { $0.path == url.path }
        entries.insert((path: url.path, bookmark: bookmark), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        persist(entries)
    }

    /// Resolves every stored bookmark, silently dropping (and persisting the
    /// drop of) any entry whose target no longer exists.
    func recentURLs() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        let entries = rawEntries()
        var resolvedEntries: [(path: String, bookmark: Data)] = []
        var resolvedURLs: [URL] = []
        for entry in entries {
            guard let url = SecurityScopedBookmark.resolve(entry.bookmark) else { continue }
            resolvedEntries.append(entry)
            resolvedURLs.append(url)
        }
        if resolvedEntries.count != entries.count {
            persist(resolvedEntries)
        }
        return resolvedURLs
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.key)
    }

    private func rawEntries() -> [(path: String, bookmark: Data)] {
        guard let array = defaults.array(forKey: Self.key) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let path = dict["path"] as? String, let bookmark = dict["bookmark"] as? Data else { return nil }
            return (path: path, bookmark: bookmark)
        }
    }

    private func persist(_ entries: [(path: String, bookmark: Data)]) {
        let array = entries.map { ["path": $0.path, "bookmark": $0.bookmark] }
        defaults.set(array, forKey: Self.key)
    }
}
