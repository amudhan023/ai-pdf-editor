import XCTest
import AuditLog
@testable import PrivacyDashboard

final class ActivityTimelineViewModelTests: XCTestCase {
    private func makeStore() throws -> AuditLogStore {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return try AuditLogStore(directory: tmp)
    }

    func testTimelineIsNewestFirst() async throws {
        let store = try makeStore()
        let first = try await store.append(eventType: .vaultRead, fieldPath: "identity.legal_name.first")
        let second = try await store.append(eventType: .fillCommitted, fieldPath: "contact.email.primary")

        let viewModel = ActivityTimelineViewModel(store: store)
        let timeline = try await viewModel.timeline()

        XCTAssertEqual(timeline.map(\.hashHex), [second.hashHex, first.hashHex])
    }

    func testTimelineFiltersByEventType() async throws {
        let store = try makeStore()
        _ = try await store.append(eventType: .vaultRead, fieldPath: "identity.legal_name.first")
        let fill = try await store.append(eventType: .fillCommitted, fieldPath: "contact.email.primary")

        let viewModel = ActivityTimelineViewModel(store: store)
        let timeline = try await viewModel.timeline(matching: AuditEntryFilter(eventTypes: [.fillCommitted]))

        XCTAssertEqual(timeline.map(\.hashHex), [fill.hashHex])
    }

    func testChainIntactOnFreshLog() async throws {
        let store = try makeStore()
        _ = try await store.append(eventType: .authEvent)

        let viewModel = ActivityTimelineViewModel(store: store)
        let intact = await viewModel.isChainIntact()

        XCTAssertTrue(intact)
    }

    func testChainStatusSurfacesTamperDetection() async throws {
        let store = try makeStore()
        _ = try await store.append(eventType: .vaultRead, fieldPath: "identity.legal_name.first")
        try await store.flipByteInSegment(index: 0, atOffset: 0)

        let viewModel = ActivityTimelineViewModel(store: store)
        let intact = await viewModel.isChainIntact()

        XCTAssertFalse(intact)
    }
}
