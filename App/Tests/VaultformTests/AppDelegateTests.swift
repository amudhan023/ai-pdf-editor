import XCTest
@testable import Vaultform

/// Composition-root smoke test: wiring `AppDelegate.init` (concrete
/// `PDFiumEngine` -> `DocumentSession` -> `DocumentViewModel`) must not
/// throw or crash before any document is opened — the acceptance criterion
/// this covers is "app stays alive" for the no-document-yet state.
@MainActor
final class AppDelegateTests: XCTestCase {
    func testInitWiresADocumentViewModelInTheEmptyState() {
        let delegate = AppDelegate()
        XCTAssertEqual(delegate.viewModel.state, .empty)
    }
}
