import AppKit
import Foundation

/// One restorable window: which document it had open and where it sat on
/// screen.
struct RestorableWindow: Equatable {
    let url: URL
    let frame: CGRect
}

/// Persists the set of open document windows across quit/relaunch — plain
/// state restoration (not `NSWindowRestoration`/secure state restoration,
/// which needs an Xcode-project storyboard hookup this SwiftPM executable
/// doesn't have; see `App/CLAUDE.md`'s "no `.xcodeproj`" note). Same
/// `UserDefaults`-injection pattern as `RecentDocumentsStore`.
final class WindowStateStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private static let key = "com.vaultform.app.restorableWindows"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Overwrites the full saved set — called once at quit with every
    /// currently-open document window, so a window closed since the last
    /// save doesn't reappear on relaunch.
    func save(_ windows: [RestorableWindow]) {
        let array: [[String: Any]] = windows.compactMap { window in
            guard let bookmark = SecurityScopedBookmark.make(for: window.url) else { return nil }
            return ["bookmark": bookmark, "frame": NSStringFromRect(window.frame)]
        }
        defaults.set(array, forKey: Self.key)
    }

    func restore() -> [RestorableWindow] {
        guard let array = defaults.array(forKey: Self.key) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let bookmark = dict["bookmark"] as? Data, let url = SecurityScopedBookmark.resolve(bookmark) else { return nil }
            let frame = (dict["frame"] as? String).map(NSRectFromString) ?? .zero
            return RestorableWindow(url: url, frame: frame)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
