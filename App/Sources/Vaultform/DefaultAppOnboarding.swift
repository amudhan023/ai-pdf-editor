import AppKit

/// "Set as default PDF app" affordance. macOS has no public API for a
/// third-party app to become the default PDF handler without the user
/// acting in Finder (`LSSetDefaultRoleHandlerForContentType` needs a private
/// entitlement Vaultform doesn't have, and `NSWorkspace.setDefaultApplication`
/// is macOS 15+ only) — so this is instructional, not automated: an alert
/// that walks the user through Finder's Get Info > Open With > Change All,
/// shown once on first launch and reachable afterward from the app menu.
@MainActor
enum DefaultAppOnboarding {
    private static let hasShownKey = "com.vaultform.app.hasShownDefaultAppOnboarding"

    static func presentIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: hasShownKey) else { return }
        defaults.set(true, forKey: hasShownKey)
        present()
    }

    static func present() {
        let alert = NSAlert()
        alert.messageText = "Make Vaultform Your Default PDF Viewer"
        alert.informativeText = "In Finder, select a PDF, choose File > Get Info, set \"Open with\" to Vaultform, then click \"Change All…\"."
        alert.addButton(withTitle: "Open Finder")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: NSHomeDirectory())
        }
    }
}
