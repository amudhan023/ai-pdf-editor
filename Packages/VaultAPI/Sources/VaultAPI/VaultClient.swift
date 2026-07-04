import Foundation

/// Whether the vault is unlocked for reads/writes. Deliberately not
/// settable through this protocol — real unlock is a biometric/password
/// flow owned by `Vault.xpc`/`Platform` (outside this Foundation-only
/// package's reach); consumers only ever observe the state here.
/// `FakeVaultClient` exposes a fake-only `setLockState(_:)` for tests.
public enum VaultLockState: String, Sendable, Codable, CaseIterable, Equatable {
    case locked
    case unlocked
}

/// Engine-neutral vault operations: profile CRUD, field CRUD, compare-read,
/// history-list CRUD, relationship edges, and crypto-shred. Every operation
/// but `lockState()` takes a `PolicyTicket` — there is no bypass path
/// (CLAUDE.md §3.3), including for implementations of this protocol used in
/// other packages' tests (`FakeVaultClient`, not a ticket-free shortcut).
public protocol VaultClient: Sendable {
    func lockState() async -> VaultLockState

    func createPerson(_ person: Person, ticket: PolicyTicket) async throws -> Person
    func person(_ id: PersonID, ticket: PolicyTicket) async throws -> Person
    func deletePerson(_ id: PersonID, ticket: PolicyTicket) async throws

    func writeField(_ field: ProfileField, ticket: PolicyTicket) async throws
    func readFields(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [ProfileField]
    func deleteField(_ path: FieldPath, for person: PersonID, ticket: PolicyTicket) async throws

    /// Conflict-detection read: reveals presence/sensitivity/verifiedAt/a
    /// fingerprint, never the raw value (ARCHITECTURE.md §5.1).
    func compareRead(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [FieldSummary]

    func writeHistoryEntry(_ entry: HistoryEntry, ticket: PolicyTicket) async throws
    func historyEntries(category: HistoryCategory, for person: PersonID, ticket: PolicyTicket) async throws -> [HistoryEntry]
    func deleteHistoryEntry(_ id: HistoryEntry.ID, for person: PersonID, ticket: PolicyTicket) async throws

    func addRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws
    func relationships(for person: PersonID, ticket: PolicyTicket) async throws -> [RelationshipEdge]
    func removeRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws

    /// Irreversible destruction of every field/history-entry/relationship
    /// owned by `person` (PRD FR-2.6's "one-click secure erase"). A real
    /// implementation destroys the encryption key material, not just the
    /// rows; this protocol only commits to the observable effect (the
    /// person and all its data become unreadable afterward).
    func cryptoShred(_ person: PersonID, ticket: PolicyTicket) async throws
}
