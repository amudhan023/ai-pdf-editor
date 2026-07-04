import Foundation
import VaultAPI

/// Everything in a `PolicyTicket` except its `signature` — the exact payload
/// that gets HMAC'd. A private type so minting and verification are
/// guaranteed to encode identically (both go through `canonicalPayload()`);
/// nothing outside this file constructs the signing bytes directly.
struct TicketClaims: Codable, Equatable {
    let id: UUID
    let operation: VaultOperation
    let personID: PersonID
    let scopedPaths: [String]
    let issuedAt: Date
    let expiresAt: Date

    init(ticket: PolicyTicket) {
        self.id = ticket.id
        self.operation = ticket.operation
        self.personID = ticket.personID
        self.scopedPaths = ticket.scopedPaths.map(\.description)
        self.issuedAt = ticket.issuedAt
        self.expiresAt = ticket.expiresAt
    }

    init(id: UUID, operation: VaultOperation, personID: PersonID, scopedPaths: [FieldPath], issuedAt: Date, expiresAt: Date) {
        self.id = id
        self.operation = operation
        self.personID = personID
        self.scopedPaths = scopedPaths.map(\.description)
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    /// Deterministic bytes: sorted keys (so field order in this struct can
    /// never change the signature) and a fixed date strategy (so encoder
    /// defaults drifting across Foundation versions can't break old
    /// signatures — this locks it to a specific, explicit representation).
    func canonicalPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }
}
