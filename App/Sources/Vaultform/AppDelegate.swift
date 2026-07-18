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
/// same constraint, not re-litigated here).
///
/// P1-07: the app is now multi-window/multi-tab — `windowControllers` holds
/// one `DocumentWindowController` (own engine/session/view model) per open
/// window, so there is no single `viewModel` property anymore; the previous
/// single-window smoke test (`AppDelegateTests`) is updated to match.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var windowControllers: [DocumentWindowController] = []
    private var memoryPressureMonitor: MemoryPressureMonitor?
    private let recentDocuments: RecentDocumentsStore
    private let windowState: WindowStateStore
    private(set) lazy var recentDocumentsMenuDelegate = RecentDocumentsMenuDelegate(store: recentDocuments) { [weak self] url in
        self?.openNewWindow(url: url)
    }

    /// Set the moment a URL is delivered via Finder "Open With"/double-click
    /// (`application(_:open:)`), which can race `applicationDidFinishLaunching`
    /// in either order — used to skip session restoration when the launch
    /// itself is "open this specific document," not "relaunch where I left off."
    private var didHandleLaunchOpen = false

    override init() {
        recentDocuments = RecentDocumentsStore()
        windowState = WindowStateStore()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.build(target: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        memoryPressureMonitor = MemoryPressureMonitor { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }

        // `application(_:open:)` for a Finder-delivered URL may already have
        // run by this point, or may still be pending — defer the
        // restore-vs-fresh-window decision to the next run loop turn so
        // that race resolves either way before we act on it.
        DispatchQueue.main.async { [weak self] in
            self?.finishLaunch()
        }
    }

    private func finishLaunch() {
        guard windowControllers.isEmpty, !didHandleLaunchOpen else { return }
        let restored = windowState.restore()
        if restored.isEmpty {
            openNewWindow(url: nil)
        } else {
            for entry in restored {
                openNewWindow(url: entry.url, frame: entry.frame)
            }
        }
        DefaultAppOnboarding.presentIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        let openDocuments = windowControllers.compactMap { controller -> RestorableWindow? in
            guard let url = controller.documentURL else { return nil }
            return RestorableWindow(url: url, frame: controller.window.frame)
        }
        windowState.save(openDocuments)
    }

    /// Handles both the toolbar/menu "Open…" action and a Finder "Open
    /// With" launch (`application(_:open:)` below) through the same path.
    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openNewWindow(url: url)
    }

    /// Finder "Open With" / double-click delivers here once the app is
    /// registered for the PDF UTI in `Info.plist` (`Scripts/build-app-bundle.sh`'s
    /// job to produce a real, launchable `.app` — see that script's header
    /// for what's proven vs. deferred).
    func application(_ application: NSApplication, open urls: [URL]) {
        didHandleLaunchOpen = true
        for url in urls {
            openNewWindow(url: url)
        }
    }

    // MARK: - Window management

    @discardableResult
    private func openNewWindow(url: URL?, frame: NSRect? = nil) -> DocumentWindowController {
        let controller = DocumentWindowController { [weak self] in self?.presentOpenPanel() }
        controller.onClose = { [weak self] closed in
            self?.windowControllers.removeAll { $0 === closed }
        }
        windowControllers.append(controller)
        if let frame {
            controller.window.setFrame(frame, display: false)
        } else {
            controller.window.center()
        }
        controller.window.makeKeyAndOrderFront(nil)
        if let url {
            Task {
                await controller.open(url: url)
                if controller.documentURL != nil {
                    recentDocuments.record(url: url)
                }
            }
        }
        return controller
    }

    private func keyDocumentWindowController() -> DocumentWindowController? {
        windowControllers.first { $0.window == NSApp.keyWindow }
            ?? windowControllers.first { $0.window.isMainWindow }
    }

    private func handleMemoryPressure() async {
        for controller in windowControllers {
            await controller.viewModel.handleMemoryPressure()
        }
    }

    // MARK: - Menu actions

    @objc func newDocumentWindow(_ sender: Any?) {
        openNewWindow(url: nil)
    }

    /// Opens a new, empty document window and merges it into the key
    /// window's tab group — `NSWindow.addTabbedWindow` is what actually
    /// makes it a tab rather than a separate window, since both windows
    /// already share `DocumentWindowController.tabbingIdentifier`. The
    /// previous key window must be captured *before* `openNewWindow`, which
    /// itself calls `makeKeyAndOrderFront` on the new window — by the time
    /// that returns, `NSApp.keyWindow` is already the new window, not the
    /// one to merge into.
    @objc func newTab(_ sender: Any?) {
        let previousKeyWindow = NSApp.keyWindow
        let newController = openNewWindow(url: nil)
        guard let keyController = windowControllers.first(where: { $0.window == previousKeyWindow }) else { return }
        keyController.window.addTabbedWindow(newController.window, ordered: .above)
        newController.window.makeKeyAndOrderFront(nil)
    }

    @objc func openDocument(_ sender: Any?) {
        presentOpenPanel()
    }

    @objc func showSetAsDefaultInstructions(_ sender: Any?) {
        DefaultAppOnboarding.present()
    }

    @objc func zoomIn(_ sender: Any?) {
        guard let controller = keyDocumentWindowController() else { return }
        controller.viewModel.setZoomMode(.custom(stepZoom(controller.viewModel.zoomMode, by: 1.25)))
    }

    @objc func zoomOut(_ sender: Any?) {
        guard let controller = keyDocumentWindowController() else { return }
        controller.viewModel.setZoomMode(.custom(stepZoom(controller.viewModel.zoomMode, by: 1 / 1.25)))
    }

    @objc func zoomActualSize(_ sender: Any?) {
        keyDocumentWindowController()?.viewModel.setZoomMode(.custom(1.0))
    }

    @objc func zoomFitWidth(_ sender: Any?) {
        keyDocumentWindowController()?.viewModel.setZoomMode(.fitWidth)
    }

    @objc func zoomFitPage(_ sender: Any?) {
        keyDocumentWindowController()?.viewModel.setZoomMode(.fitPage)
    }

    /// `.fitWidth`/`.fitPage` have no single scale value to step from (it
    /// depends on the current viewport), so stepping from either lands on
    /// 100% first — matches Preview's behavior of resolving fit-mode to a
    /// concrete percentage on the first explicit zoom action.
    private func stepZoom(_ mode: ZoomMode, by factor: Double) -> Double {
        switch mode {
        case .custom(let value): return value * factor
        case .fitWidth, .fitPage: return factor >= 1 ? 1.25 : 0.8
        }
    }
}
