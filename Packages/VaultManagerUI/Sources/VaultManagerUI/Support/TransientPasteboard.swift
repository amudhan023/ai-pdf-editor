import AppKit

/// Copies a revealed vault value to the general pasteboard as transient
/// (CLAUDE.md §7.4: "vault values on the pasteboard must use transient
/// pasteboard type + expiry"). "Transient" here is the `org.nspasteboard.*`
/// community convention (respected by clipboard managers/iCloud sync) plus a
/// changeCount-gated auto-clear — there's no first-party macOS API for
/// pasteboard expiry, so this is the standard workaround, not a home-rolled
/// invention.
enum TransientPasteboard {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func copy(_ value: String, expiresAfter seconds: TimeInterval = 30) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        pasteboard.setString("", forType: concealedType)
        pasteboard.setString("", forType: transientType)
        let changeCount = pasteboard.changeCount
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
