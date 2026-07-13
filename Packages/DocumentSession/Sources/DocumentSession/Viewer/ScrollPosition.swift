import Foundation

/// Where the reader was last positioned in a document — page index plus a
/// vertical fraction within that page (0 = top, 1 = bottom). Persisted so
/// reopening a document restores roughly where the user left off.
public struct ScrollPosition: Sendable, Equatable, Codable {
    public let page: Int
    public let verticalFraction: Double

    public init(page: Int, verticalFraction: Double) {
        self.page = page
        self.verticalFraction = min(1, max(0, verticalFraction))
    }
}

/// Keyed by the document's URL only — this stores a page index and a
/// fraction, never document content, text, or vault values (CLAUDE.md §8.1).
public protocol ScrollPositionStoring: Sendable {
    func position(for url: URL) -> ScrollPosition?
    func save(_ position: ScrollPosition, for url: URL)
}

/// `UserDefaults`-backed implementation for the app; tests use an
/// in-memory `Fake` instead (never touch real `UserDefaults` from tests).
public final class UserDefaultsScrollPositionStore: ScrollPositionStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func position(for url: URL) -> ScrollPosition? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key(for: url)) else { return nil }
        return try? JSONDecoder().decode(ScrollPosition.self, from: data)
    }

    public func save(_ position: ScrollPosition, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(position) else { return }
        defaults.set(data, forKey: key(for: url))
    }

    private func key(for url: URL) -> String {
        "com.vaultform.documentSession.scrollPosition.\(url.path)"
    }
}

/// In-memory fake for tests (CLAUDE.md §5 `Fake*` naming — shipped in the
/// library, not `Tests/`, so `App/` can use it in previews too).
public final class FakeScrollPositionStore: ScrollPositionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL: ScrollPosition] = [:]

    public init() {}

    public func position(for url: URL) -> ScrollPosition? {
        lock.lock()
        defer { lock.unlock() }
        return storage[url]
    }

    public func save(_ position: ScrollPosition, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        storage[url] = position
    }
}
