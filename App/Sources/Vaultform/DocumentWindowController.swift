import AppKit
import SwiftUI
import DocEngineHost
import DocumentSession

/// One document window: its own `PDFiumEngine`/`DocumentSession`/
/// `DocumentViewModel` triple (ARCHITECTURE.md §2.3 — "one DocEngine.xpc
/// instance per document must survive tab/window moves"; today that's one
/// in-process engine per window, same in-process-not-XPC constraint
/// `AppDelegate`'s original doc comment already flagged). Tabbing is native
/// `NSWindow` tabbing (`tabbingIdentifier` + `.preferred`), not a custom
/// tab strip — windows sharing the identifier merge into one tabbed group
/// automatically and AppKit manages the tab bar UI and its Window-menu
/// items (Show Next/Previous Tab, Merge All Windows) itself.
@MainActor
final class DocumentWindowController: NSObject, NSWindowDelegate {
    static let tabbingIdentifier = "com.vaultform.document"

    let window: NSWindow
    let viewModel: DocumentViewModel
    private(set) var documentURL: URL?

    /// Fires once the window is about to close so the owner (`AppDelegate`)
    /// can drop it from the tracked list; window-close is the only lifecycle
    /// event that removes a controller.
    var onClose: ((DocumentWindowController) -> Void)?

    init(onOpenPanel: @escaping () -> Void) {
        let engine = PDFiumEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine, outlineReader: engine, textEditor: engine)
        let viewModel = DocumentViewModel(session: session)
        self.viewModel = viewModel

        let rootView = RootView(viewModel: viewModel, onOpen: onOpenPanel)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Vaultform"
        window.setContentSize(NSSize(width: 900, height: 1000))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.tabbingMode = .preferred
        self.window = window

        super.init()
        window.delegate = self
    }

    /// Only records `url` as this window's document (for the title bar,
    /// recents, and restoration) if the open actually succeeded — a failed
    /// open must not get persisted into `WindowStateStore` and silently
    /// re-attempted, and re-attempted, on every future relaunch.
    func open(url: URL) async {
        await viewModel.open(url: url)
        guard case .loaded = viewModel.state else { return }
        documentURL = url
        window.title = url.lastPathComponent
        window.representedURL = url
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}
