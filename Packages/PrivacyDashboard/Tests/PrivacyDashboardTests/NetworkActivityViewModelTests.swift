import XCTest
import AuditLog
@testable import PrivacyDashboard

/// In-memory `NetworkConnectionSettingsStore` for tests — avoids touching
/// real `UserDefaults` (same rationale as `FakeVaultClient`: a fake, not a
/// mock of a concrete type).
private final class FakeNetworkConnectionSettingsStore: NetworkConnectionSettingsStore, @unchecked Sendable {
    private var overrides: [NetworkConnectionKind: Bool] = [:]

    func isEnabled(_ kind: NetworkConnectionKind) -> Bool {
        overrides[kind] ?? kind.defaultEnabled
    }

    func setEnabled(_ kind: NetworkConnectionKind, _ enabled: Bool) {
        overrides[kind] = enabled
    }
}

/// Stands in for the real dialer that would sit behind update-check/license
/// validation: it only "connects" if the settings store says the kind is
/// enabled, mirroring the contract `NetworkActivityViewModel`'s doc comment
/// describes (enforcement happens at the call site, not in this view-model).
private struct FakeNetworkDialer {
    let settings: NetworkConnectionSettingsStore
    private(set) var didConnect: [NetworkConnectionKind] = []

    mutating func dial(_ kind: NetworkConnectionKind) {
        guard settings.isEnabled(kind) else { return }
        didConnect.append(kind)
    }
}

final class NetworkActivityViewModelTests: XCTestCase {
    private func makeStore() throws -> AuditLogStore {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return try AuditLogStore(directory: tmp)
    }

    func testFreshInstallHasNoNetworkEvents() async throws {
        let store = try makeStore()
        _ = try await store.append(eventType: .vaultRead, fieldPath: "identity.legal_name.first")

        let viewModel = NetworkActivityViewModel(settings: FakeNetworkConnectionSettingsStore(), auditLog: store)

        let hasEvent = try await viewModel.hasAnyNetworkEvent()
        XCTAssertFalse(hasEvent)

        let statuses = try await viewModel.statuses()
        XCTAssertTrue(statuses.allSatisfy { $0.lastContactAt == nil })
    }

    func testStatusesReflectDefaultsAndLastContact() async throws {
        let store = try makeStore()
        let event = try await store.append(eventType: .networkEvent)

        let viewModel = NetworkActivityViewModel(settings: FakeNetworkConnectionSettingsStore(), auditLog: store)
        let statuses = try await viewModel.statuses()

        let updateCheck = statuses.first { $0.kind == .updateCheck }
        let telemetry = statuses.first { $0.kind == .optInTelemetry }
        XCTAssertEqual(updateCheck?.isEnabled, true)
        XCTAssertEqual(telemetry?.isEnabled, false)
        XCTAssertEqual(updateCheck?.lastContactAt?.timeIntervalSince1970 ?? 0, event.timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func testTogglingOffPersistsAndProvablyPreventsTheConnection() async throws {
        let settings = FakeNetworkConnectionSettingsStore()
        let store = try makeStore()
        let viewModel = NetworkActivityViewModel(settings: settings, auditLog: store)

        viewModel.setEnabled(false, for: .updateCheck)

        let statuses = try await viewModel.statuses()
        XCTAssertEqual(statuses.first { $0.kind == .updateCheck }?.isEnabled, false)

        var dialer = FakeNetworkDialer(settings: settings)
        dialer.dial(.updateCheck)
        XCTAssertTrue(dialer.didConnect.isEmpty)
    }
}
