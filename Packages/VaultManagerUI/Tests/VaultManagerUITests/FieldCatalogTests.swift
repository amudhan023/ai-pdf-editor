import XCTest
import VaultAPI
@testable import VaultManagerUI

final class FieldCatalogTests: XCTestCase {
    /// Every literal in `FieldCatalog` must actually parse — this is the
    /// regression guard for the "runtime silently drops a typo'd row"
    /// failure mode `FieldCatalog.entry` documents.
    func testEverySectionHasNonEmptyKnownGoodCatalog() {
        for section: FieldSection in [.identity, .contact, .employment, .financial] {
            XCTAssertFalse(FieldCatalog.entries(for: section).isEmpty, "\(section) should have catalog rows")
        }
    }

    func testCatalogPathsBelongToTheirDeclaredSection() {
        for section: FieldSection in [.identity, .contact, .employment, .financial] {
            for entry in FieldCatalog.entries(for: section) {
                XCTAssertEqual(entry.path.section, section)
            }
        }
    }

    func testUnknownSectionReturnsEmpty() {
        XCTAssertTrue(FieldCatalog.entries(for: .health).isEmpty)
    }
}
