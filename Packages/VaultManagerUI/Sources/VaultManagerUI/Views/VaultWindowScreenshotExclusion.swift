import SwiftUI
import AppKit

/// Excludes the hosting window from screen recordings/screenshots (FR-2.5's
/// "screenshot exclusion on vault windows") by setting `NSWindow.sharingType
/// = .none` once the view's window is available. SwiftUI has no direct
/// window-property modifier, so this goes through the standard
/// `NSViewRepresentable` bridge to reach the AppKit window.
struct VaultWindowScreenshotExclusion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.sharingType = .none
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.sharingType = .none
    }
}

extension View {
    /// Applies to the vault window's root view so no window content is
    /// ever capturable by screen sharing/recording (CLAUDE.md §8 privacy
    /// posture extended to the OS screen-capture surface).
    public func excludedFromScreenCapture() -> some View {
        background(VaultWindowScreenshotExclusion())
    }
}
