import XCTest
@testable import Vaultform

/// Composition-root smoke test. `AppDelegate.init` no longer wires a single
/// window (P1-07 made the app multi-window) — `NSApplicationDelegate`
/// lifecycle methods that create windows need a running `NSApplication`,
/// which XCTest doesn't provide, so this only pins what's true before
/// `applicationDidFinishLaunching` runs: construction doesn't throw/crash
/// and no window exists yet.
@MainActor
final class AppDelegateTests: XCTestCase {
    func testInitDoesNotCreateAnyWindow() {
        let delegate = AppDelegate()
        XCTAssertTrue(delegate.windowControllers.isEmpty)
    }
}
