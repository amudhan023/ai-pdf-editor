import Foundation
import VaultAPI

/// Capability seam for recording a sensitive-field reveal event. `AuditLog`
/// is not on this package's import allowlist (only the app composition root
/// wires reveal events through to it) — CLAUDE.md §8.3 requires reveal
/// events to be logged, but the log entry itself (IDs/paths/hashes, never
/// values) is `AuditLog`'s shape to own, not this UI package's.
public protocol VaultRevealAuditing: Sendable {
    func recordReveal(path: FieldPath, personID: PersonID)
}
