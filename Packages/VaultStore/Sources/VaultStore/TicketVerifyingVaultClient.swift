import Foundation
import CryptoKit
import PolicyKit
import VaultAPI

/// Cryptographic signature + replay verification failed. Deliberately its
/// own type rather than a new `VaultAPI.VaultError` case — `VaultError` is
/// part of the frozen `VaultAPI` seam (ADR-007); adding a case there for an
/// internal decorator's failure mode would need an ADR for no real benefit,
/// since callers of this decorator already handle arbitrary `Error`.
public enum TicketVerificationFailure: Error, Sendable, Equatable {
    case expired
    case invalidSignature
    case replayed
}

/// Wraps any `VaultClient` and adds real HMAC signature verification
/// (`PolicyKit.TicketVerifier`) plus replay rejection (`PolicyKit.ReplayGuard`)
/// in front of every call — the "every privileged call requires a verified
/// PolicyTicket" leg of this task's requirements.
///
/// Kept separate from `SQLCipherVaultStore` deliberately:
/// `VaultAPI.VaultConformanceSuite` mints tickets with a dummy, empty
/// `signature` by its own documented design ("signature verification is
/// PolicyKit's concern... out of scope for this protocol layer entirely" —
/// see that type's doc comment), so the conformance suite must run against
/// the undecorated store. Real callers (the XPC surface) should always go
/// through this decorator, never the bare store — see
/// `Packages/VaultStore/CLAUDE.md`.
public actor TicketVerifyingVaultClient<Inner: VaultClient>: VaultClient {
    // `internal` rather than `private`: the `Inner == SQLCipherVaultStore`
    // extensions in Operations/ (batch accept-set, history date-range
    // queries — capabilities beyond the frozen `VaultClient` seam,
    // ADR-007) need `inner` and `verify` to add the same signature/replay
    // check in front of those calls.
    let inner: Inner
    private let signingKey: SymmetricKey
    private let replayGuard: ReplayGuard

    public init(wrapping inner: Inner, signingKey: SymmetricKey, replayGuard: ReplayGuard = ReplayGuard()) {
        self.inner = inner
        self.signingKey = signingKey
        self.replayGuard = replayGuard
    }

    public func lockState() async -> VaultLockState {
        await inner.lockState()
    }

    public func createPerson(_ person: Person, ticket: PolicyTicket) async throws -> Person {
        try await verify(ticket)
        return try await inner.createPerson(person, ticket: ticket)
    }

    public func person(_ id: PersonID, ticket: PolicyTicket) async throws -> Person {
        try await verify(ticket)
        return try await inner.person(id, ticket: ticket)
    }

    public func deletePerson(_ id: PersonID, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.deletePerson(id, ticket: ticket)
    }

    public func writeField(_ field: ProfileField, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.writeField(field, ticket: ticket)
    }

    public func readFields(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [ProfileField] {
        try await verify(ticket)
        return try await inner.readFields(paths, for: person, ticket: ticket)
    }

    public func deleteField(_ path: FieldPath, for person: PersonID, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.deleteField(path, for: person, ticket: ticket)
    }

    public func compareRead(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [FieldSummary] {
        try await verify(ticket)
        return try await inner.compareRead(paths, for: person, ticket: ticket)
    }

    public func writeHistoryEntry(_ entry: HistoryEntry, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.writeHistoryEntry(entry, ticket: ticket)
    }

    public func historyEntries(category: HistoryCategory, for person: PersonID, ticket: PolicyTicket) async throws -> [HistoryEntry] {
        try await verify(ticket)
        return try await inner.historyEntries(category: category, for: person, ticket: ticket)
    }

    public func deleteHistoryEntry(_ id: HistoryEntry.ID, for person: PersonID, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.deleteHistoryEntry(id, for: person, ticket: ticket)
    }

    public func addRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.addRelationship(edge, ticket: ticket)
    }

    public func relationships(for person: PersonID, ticket: PolicyTicket) async throws -> [RelationshipEdge] {
        try await verify(ticket)
        return try await inner.relationships(for: person, ticket: ticket)
    }

    public func removeRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.removeRelationship(edge, ticket: ticket)
    }

    public func cryptoShred(_ person: PersonID, ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.cryptoShred(person, ticket: ticket)
    }

    func verify(_ ticket: PolicyTicket) async throws {
        switch TicketVerifier.verify(ticket, signingKey: signingKey) {
        case .success:
            break
        case .failure(.expired):
            throw TicketVerificationFailure.expired
        case .failure(.invalidSignature):
            throw TicketVerificationFailure.invalidSignature
        case .failure(.replayed):
            throw TicketVerificationFailure.replayed
        }
        guard await replayGuard.consume(ticket.id) else {
            throw TicketVerificationFailure.replayed
        }
    }
}
