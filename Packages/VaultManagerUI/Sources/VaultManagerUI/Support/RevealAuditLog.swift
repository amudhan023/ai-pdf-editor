import Foundation
import OSLog
import VaultAPI

/// Logs that a sensitive field was revealed — never the value itself
/// (CLAUDE.md §16: "no document content, vault values... at any log level").
/// Uses `OSLog` directly rather than `AuditLog` (the package's hash-chained,
/// structured audit trail) because `AuditLog` isn't in this package's import
/// allowlist; wiring reveal events into the real audit trail is composition
/// root/session-layer follow-up, flagged in this task's Handoff, not solved
/// here by adding a dependency this package isn't allowed.
enum RevealAuditLog {
    private static let logger = Logger(subsystem: "com.vaultform.app", category: "VaultManagerUI.reveal")

    /// Logs the field's section (e.g. `identity`) and sensitivity, not the
    /// full path or value — a path's leaf segments can themselves be
    /// semantically revealing (e.g. `licenses.firearm.permit_number`).
    static func revealed(path: FieldPath, personID: PersonID, sensitivity: SensitivityTier) {
        logger.notice("reveal person=\(personID.value, privacy: .public) section=\(path.section.rawValue, privacy: .public) sensitivity=\(sensitivity.rawValue, privacy: .public)")
    }
}
