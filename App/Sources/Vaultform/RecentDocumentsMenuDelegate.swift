import AppKit

/// Rebuilds the "Open Recent" submenu from `RecentDocumentsStore` each time
/// it opens — `NSMenuItem`s can't data-bind, and recents change between
/// menu opens (a fresh `Open…` may have just run), so a delegate callback is
/// simpler than manually diffing item lists on every `record(url:)`.
@MainActor
final class RecentDocumentsMenuDelegate: NSObject, NSMenuDelegate {
    private let store: RecentDocumentsStore
    private let onSelect: (URL) -> Void

    init(store: RecentDocumentsStore, onSelect: @escaping (URL) -> Void) {
        self.store = store
        self.onSelect = onSelect
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = store.recentURLs()
        if urls.isEmpty {
            let empty = menu.addItem(withTitle: "No Recent Documents", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            return
        }
        for url in urls {
            let item = menu.addItem(withTitle: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.toolTip = url.path
        }
        menu.addItem(.separator())
        let clear = menu.addItem(withTitle: "Clear Menu", action: #selector(clearRecents(_:)), keyEquivalent: "")
        clear.target = self
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onSelect(url)
    }

    @objc private func clearRecents(_ sender: NSMenuItem) {
        store.clear()
    }
}
