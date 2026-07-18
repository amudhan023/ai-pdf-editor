import Foundation

/// Shared bookmark encode/resolve used by both `RecentDocumentsStore` (open
/// history) and `WindowStateStore` (restoration) — both persist a file
/// reference that must survive relaunch even if the app isn't sandboxed
/// today (P1-07's "recents menu via security-scoped bookmarks" requirement;
/// `.withSecurityScope` is harmless to request outside a sandbox and keeps
/// this correct the day an entitlement adds one, per DocEngineHost's
/// existing `startAccessingSecurityScopedResource` use).
enum SecurityScopedBookmark {
    static func make(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Returns `nil` when the bookmark no longer resolves (file moved or
    /// deleted) — callers drop that entry rather than surfacing an error,
    /// since a stale recents/restoration entry is expected steady-state,
    /// not a failure.
    static func resolve(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        return url
    }
}
