import Foundation
import GRDB
import VaultAPI

/// Date-range history query beyond the frozen `VaultClient` seam
/// (ADR-007) — ARCHITECTURE.md §8.2's history lists are "first-class
/// tables... because gap-detection queries need them"; this is the overlap
/// query gap-detection is built on (the gap-detection algorithm itself is
/// out of scope here, per that section's "later").
extension SQLCipherVaultStore {
    /// Entries in `category` for `person` whose date range overlaps
    /// `range`. An entry with a `nil` `rangeEnd` is "ongoing" and overlaps
    /// any query whose start is at or before now; a `nil` `range.end` on
    /// the query side means "open-ended, up to present/future."
    public func historyEntries(
        category: HistoryCategory,
        overlapping range: DateRange,
        for person: PersonID,
        ticket: PolicyTicket
    ) async throws -> [HistoryEntry] {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .read, person: person)
        try await emitAccess(.read, person: person, ticket: ticket)
        return try await pool.read { db in
            var request = HistoryEntryRow
                .filter(Column("personID") == person.value.uuidString && Column("category") == category.rawValue)
                .filter(Column("rangeEnd") == nil || Column("rangeEnd") >= range.start)
            if let queryEnd = range.end {
                request = request.filter(Column("rangeStart") <= queryEnd)
            }
            let entryRows = try request.order(Column("rangeStart")).fetchAll(db)
            return try entryRows.map { entryRow in
                let fieldRows = try HistoryFieldEntryRow
                    .filter(Column("historyEntryID") == entryRow.id)
                    .fetchAll(db)
                let fields = try fieldRows.map { try $0.asDomain() }
                return try entryRow.asDomain(fields: fields)
            }
        }
    }
}

extension TicketVerifyingVaultClient where Inner == SQLCipherVaultStore {
    public func historyEntries(
        category: HistoryCategory,
        overlapping range: DateRange,
        for person: PersonID,
        ticket: PolicyTicket
    ) async throws -> [HistoryEntry] {
        try await verify(ticket)
        return try await inner.historyEntries(category: category, overlapping: range, for: person, ticket: ticket)
    }
}
