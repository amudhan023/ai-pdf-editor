import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DocEngineHost
import DocumentSession

/// The composition root (root CLAUDE.md §3.1 layering: Presentation ->
/// Application -> Domain -> Infrastructure). This is the one place in the
/// app allowed to name a concrete engine (`PDFiumEngine`, Infrastructure) —
/// everything it hands to `DocumentSession`/`DocumentViewModel` is behind
/// `PDFEngineAPI` protocols from there on.
///
/// `PDFiumEngine` is wired in-process, not across a real `DocEngine.xpc`
/// process boundary: genuine cross-process XPC needs proper `.xpc` bundle
/// embedding via `xpcproxy`, which requires a real Xcode app bundle
/// (confirmed empirically in `Services/DocEngineService`'s P0-05 Journal —
/// same constraint, not re-litigated here). This task's Requirements ask
/// for "naive tiling... using P0-06 tiles," not the process split; moving
/// `PDFiumEngine` behind the real `DocEngine.xpc` boundary is follow-up
/// scope (filed alongside this task, see its Journal).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    let viewModel: DocumentViewModel

    override init() {
        let engine = PDFiumEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine)
        viewModel = DocumentViewModel(session: session)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = RootView(viewModel: viewModel, onOpen: { [weak self] in self?.presentOpenPanel() })
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Vaultform"
        window.setContentSize(NSSize(width: 900, height: 1000))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Handles both the toolbar/menu "Open…" action and a Finder "Open
    /// With" launch (`application(_:open:)` below) through the same path.
    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url: url)
    }

    /// Finder "Open With" / double-click delivers here once the app is
    /// registered for the PDF UTI in `Info.plist` (`Scripts/build-app-bundle.sh`'s
    /// job to produce a real, launchable `.app` — see that script's header
    /// for what's proven vs. deferred).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        open(url: url)
    }

    private func open(url: URL) {
        Task { await viewModel.open(url: url) }
    }
}
