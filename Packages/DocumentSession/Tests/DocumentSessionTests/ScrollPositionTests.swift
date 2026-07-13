import XCTest
@testable import DocumentSession

final class ScrollPositionTests: XCTestCase {
    func testVerticalFractionIsClampedIntoZeroToOne() {
        XCTAssertEqual(ScrollPosition(page: 0, verticalFraction: -1).verticalFraction, 0)
        XCTAssertEqual(ScrollPosition(page: 0, verticalFraction: 2).verticalFraction, 1)
        XCTAssertEqual(ScrollPosition(page: 0, verticalFraction: 0.5).verticalFraction, 0.5)
    }

    func testFakeStoreRoundTripsPerURL() {
        let store = FakeScrollPositionStore()
        let urlA = URL(fileURLWithPath: "/tmp/a.pdf")
        let urlB = URL(fileURLWithPath: "/tmp/b.pdf")

        store.save(ScrollPosition(page: 3, verticalFraction: 0.4), for: urlA)

        XCTAssertEqual(store.position(for: urlA), ScrollPosition(page: 3, verticalFraction: 0.4))
        XCTAssertNil(store.position(for: urlB))
    }

    func testUserDefaultsStoreRoundTripsThroughEncodingAndIsolatesSuites() {
        let suiteName = "com.vaultform.documentSession.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not create an isolated UserDefaults suite for the test")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsScrollPositionStore(defaults: defaults)
        let url = URL(fileURLWithPath: "/tmp/doc.pdf")

        XCTAssertNil(store.position(for: url))

        store.save(ScrollPosition(page: 7, verticalFraction: 0.9), for: url)

        XCTAssertEqual(store.position(for: url), ScrollPosition(page: 7, verticalFraction: 0.9))
    }
}
