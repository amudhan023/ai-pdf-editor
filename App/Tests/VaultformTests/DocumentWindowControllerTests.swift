import XCTest
@testable import Vaultform

@MainActor
final class DocumentWindowControllerTests: XCTestCase {
    func testInitCreatesAWindowWithSharedTabbingIdentity() {
        let controller = DocumentWindowController(onOpenPanel: {})

        XCTAssertEqual(controller.window.tabbingIdentifier, DocumentWindowController.tabbingIdentifier)
        XCTAssertEqual(controller.viewModel.state, .empty)
        XCTAssertNil(controller.documentURL)
    }

    func testOpeningAMissingFileLeavesDocumentURLUnset() async {
        let controller = DocumentWindowController(onOpenPanel: {})

        await controller.open(url: URL(fileURLWithPath: "/nonexistent/does-not-exist.pdf"))

        XCTAssertNil(controller.documentURL, "a failed open must not be recorded as this window's document")
    }

    func testWindowWillCloseInvokesOnClose() {
        let controller = DocumentWindowController(onOpenPanel: {})
        let closed = expectation(description: "onClose invoked")
        controller.onClose = { closedController in
            XCTAssertTrue(closedController === controller)
            closed.fulfill()
        }

        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        wait(for: [closed], timeout: 1.0)
    }
}
