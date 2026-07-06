import XCTest
import AppKit
@testable import VaultManagerUI

@MainActor
final class TransientPasteboardWriterTests: XCTestCase {
    func testCopyWritesStringAndMarkerTypes() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let writer = TransientPasteboardWriter(pasteboard: pasteboard)

        writer.copyTransiently("123-45-6789", expiry: 30)

        XCTAssertEqual(pasteboard.string(forType: .string), "123-45-6789")
        XCTAssertNotNil(pasteboard.data(forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
        XCTAssertNotNil(pasteboard.data(forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
    }

    func testClearAfterExpiryOnlyIfUntouched() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let writer = TransientPasteboardWriter(pasteboard: pasteboard)

        writer.copyTransiently("secret", expiry: 0.05)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNil(pasteboard.string(forType: .string), "value must be cleared after expiry")
    }

    func testClearIsSkippedIfPasteboardChangedSince() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let writer = TransientPasteboardWriter(pasteboard: pasteboard)

        writer.copyTransiently("secret", expiry: 0.05)
        pasteboard.clearContents()
        pasteboard.setString("unrelated copy", forType: .string)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(pasteboard.string(forType: .string), "unrelated copy")
    }
}
