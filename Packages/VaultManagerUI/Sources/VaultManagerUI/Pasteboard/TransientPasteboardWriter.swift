import AppKit

/// Copies a revealed vault value to the pasteboard as transient and
/// self-clearing (CLAUDE.md §7.4: "Vault values on the pasteboard must use
/// transient pasteboard type + expiry"). AppKit has no first-party
/// "transient" pasteboard API; declaring the `org.nspasteboard.*` marker
/// types alongside the real payload is the de-facto convention third-party
/// clipboard managers honor (nspasteboard.org) — this is the standard
/// mechanism, not a workaround.
@MainActor
public final class TransientPasteboardWriter {
    public nonisolated static let defaultExpiry: TimeInterval = 30

    private let pasteboard: NSPasteboard
    private var clearWorkItem: DispatchWorkItem?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Writes `plaintext`, marks it transient/concealed, and schedules a
    /// clear after `expiry` — but only if nothing else has since overwritten
    /// the pasteboard (guarded by `changeCount`, so a user's next unrelated
    /// copy isn't clobbered by a stale timer).
    public func copyTransiently(_ plaintext: String, expiry: TimeInterval = defaultExpiry) {
        pasteboard.clearContents()
        pasteboard.setString(plaintext, forType: .string)
        pasteboard.setString("", forType: Self.concealedType)
        pasteboard.setString("", forType: Self.transientType)

        let changeCount = pasteboard.changeCount
        clearWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pasteboard.changeCount == changeCount else { return }
            self.pasteboard.clearContents()
        }
        clearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + expiry, execute: workItem)
    }

    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
}
