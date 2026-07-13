import Foundation
import AuditLog

/// The closed set of network connections this product ever makes (CLAUDE.md
/// §7.1: "No network calls anywhere except the enumerated, consented
/// app-level paths"). Deliberately not open-ended — a dashboard row for a
/// connection that isn't one of these three would itself be evidence of a
/// red-line violation elsewhere in the app.
public enum NetworkConnectionKind: String, Sendable, CaseIterable, Equatable {
    case updateCheck
    case licenseValidation
    case optInTelemetry

    /// All three are opt-in in spirit; only `updateCheck`/`licenseValidation`
    /// default on (needed for the app to function/license itself).
    /// Telemetry defaults off per CLAUDE.md §8.2.
    public var defaultEnabled: Bool {
        switch self {
        case .updateCheck, .licenseValidation: true
        case .optInTelemetry: false
        }
    }
}

/// Settings-backed on/off state for each `NetworkConnectionKind` — the
/// dashboard's toggle surface. A protocol (not a concrete `UserDefaults`
/// type) so the toggle-enforcement path can be driven by a fake in tests
/// without touching real user defaults.
public protocol NetworkConnectionSettingsStore: Sendable {
    func isEnabled(_ kind: NetworkConnectionKind) -> Bool
    func setEnabled(_ kind: NetworkConnectionKind, _ enabled: Bool)
}

/// `UserDefaults`-backed implementation for real app use.
public final class UserDefaultsNetworkConnectionSettingsStore: NetworkConnectionSettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "privacyDashboard.networkConnection."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isEnabled(_ kind: NetworkConnectionKind) -> Bool {
        let key = keyPrefix + kind.rawValue
        guard defaults.object(forKey: key) != nil else { return kind.defaultEnabled }
        return defaults.bool(forKey: key)
    }

    public func setEnabled(_ kind: NetworkConnectionKind, _ enabled: Bool) {
        defaults.set(enabled, forKey: keyPrefix + kind.rawValue)
    }
}

/// One row of the Network view: a connection kind, its current toggle
/// state, and the last time an audit-logged `networkEvent` was observed
/// (`nil` on a fresh install — the acceptance criterion this task names).
public struct NetworkConnectionStatus: Sendable, Equatable {
    public let kind: NetworkConnectionKind
    public let isEnabled: Bool
    public let lastContactAt: Date?
}

/// Combines the settings store (on/off) with the audit log (last-contact
/// timestamps, via `.networkEvent` entries) into the Network view's rows.
public struct NetworkActivityViewModel: Sendable {
    private let settings: NetworkConnectionSettingsStore
    private let auditLog: AuditLogStore

    public init(settings: NetworkConnectionSettingsStore, auditLog: AuditLogStore) {
        self.settings = settings
        self.auditLog = auditLog
    }

    /// Toggling a connection off here only records the *preference*; the
    /// enforcement — actually refusing to open the connection — happens at
    /// the call site that would have made it (CLAUDE.md §7.1: XPC services
    /// have no network entitlement at all, and the two app-level paths this
    /// enumerates are expected to check this setting before dialing out).
    public func setEnabled(_ enabled: Bool, for kind: NetworkConnectionKind) {
        settings.setEnabled(kind, enabled)
    }

    public func statuses() async throws -> [NetworkConnectionStatus] {
        let networkEntries = try await auditLog.entries(
            matching: AuditEntryFilter(eventTypes: [.networkEvent])
        )
        let lastContact = networkEntries.map(\.timestamp).max()
        return NetworkConnectionKind.allCases.map { kind in
            NetworkConnectionStatus(
                kind: kind,
                isEnabled: settings.isEnabled(kind),
                lastContactAt: lastContact
            )
        }
    }

    /// Fresh-install acceptance criterion: zero network events recorded.
    public func hasAnyNetworkEvent() async throws -> Bool {
        try await !auditLog.entries(matching: AuditEntryFilter(eventTypes: [.networkEvent])).isEmpty
    }
}
