import Foundation
import GRDB
import VaultAPI

/// Batch field write beyond the frozen `VaultClient` seam (ADR-007) — the
/// ingestion "accept set" (CLAUDE.md §11 requirement): a review-approved
/// batch of fields commits as a single transaction, all-or-nothing, so a
/// mid-batch failure (e.g. a scope mismatch on one field) never leaves a
/// partially-applied accept behind.
extension SQLCipherVaultStore {
    public func acceptFields(_ fields: [ProfileField], ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        for field in fields {
            try checkTicket(ticket, operation: .write, person: field.personID, path: field.path)
        }
        if let personID = fields.first?.personID {
            try await emitAccess(.write, person: personID, paths: fields.map(\.path), ticket: ticket)
        }
        let rows = try fields.map { try ProfileFieldRow($0) }
        try await pool.write { db in
            for (field, row) in zip(fields, rows) {
                guard try PersonRow.filter(key: field.personID.value.uuidString).fetchCount(db) > 0 else {
                    throw VaultError.personNotFound(field.personID)
                }
                try row.save(db)
            }
        }
    }
}

extension TicketVerifyingVaultClient where Inner == SQLCipherVaultStore {
    public func acceptFields(_ fields: [ProfileField], ticket: PolicyTicket) async throws {
        try await verify(ticket)
        try await inner.acceptFields(fields, ticket: ticket)
    }
}
