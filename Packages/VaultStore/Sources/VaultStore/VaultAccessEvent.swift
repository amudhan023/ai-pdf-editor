import Foundation
import VaultAPI

/// One field-scoped vault access: emitted by `SQLCipherVaultStore` for
/// every read/write/compare-read/history/relationship call once its
/// `PolicyTicket` passes structural validation (P1-10 requirement: "access
/// events emitted for every read/write with field paths + ticket IDs").
/// Carries no value — CLAUDE.md §8.3's "audit log entries carry IDs,
/// paths, and hashes, never values" applies to this event just as much as
/// to the eventual `AuditLog` entries it feeds (P1-15's scope for actually
/// persisting them); the type has no value slot by construction.
public struct VaultAccessEvent: Sendable, Equatable {
    public let operation: VaultOperation
    public let personID: PersonID
    public let paths: [FieldPath]
    public let ticketID: UUID
    public let at: Date
}
