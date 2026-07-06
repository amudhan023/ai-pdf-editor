import Foundation
import VaultAPI

/// One history entry plus whether it overlaps another entry in the same
/// list (PRD's gap/overlap-detection UX for address/employment/education/
/// travel history). Computed client-side from whatever `historyEntries`
/// returns — `VaultClient` has no server-side overlap query.
public struct HistoryRow: Sendable, Equatable, Identifiable {
    public let entry: HistoryEntry
    public let overlapsAnother: Bool
    public var id: UUID { entry.id }
}

/// Drives one history category's list editor for a profile (e.g. "Address
/// history"). One instance per `(personID, category)` pair.
@MainActor
public final class HistoryListViewModel: ObservableObject {
    @Published public private(set) var rows: [HistoryRow] = []
    @Published public private(set) var lastError: VaultError?

    public let personID: PersonID
    public let category: HistoryCategory
    private let client: any VaultClient
    private let tickets: any VaultTicketProviding

    public init(personID: PersonID, category: HistoryCategory, client: any VaultClient, tickets: any VaultTicketProviding) {
        self.personID = personID
        self.category = category
        self.client = client
        self.tickets = tickets
    }

    public func refresh() async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .read, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            let entries = try await client.historyEntries(category: category, for: personID, ticket: ticket)
            rows = Self.rowsWithOverlaps(entries)
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure: leave the prior list displayed.
        }
    }

    public func addEntry(range: DateRange, fields: [HistoryFieldEntry]) async {
        let entry = HistoryEntry(personID: personID, category: category, range: range, fields: fields)
        await write(entry)
    }

    public func updateEntry(_ entry: HistoryEntry) async {
        await write(entry)
    }

    private func write(_ entry: HistoryEntry) async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            try await client.writeHistoryEntry(entry, ticket: ticket)
            await refresh()
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure: leave the prior list displayed.
        }
    }

    public func deleteEntry(_ id: HistoryEntry.ID) async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            try await client.deleteHistoryEntry(id, for: personID, ticket: ticket)
            rows.removeAll { $0.id == id }
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure: leave the prior list displayed.
        }
    }

    /// Two ranges overlap when both have started and neither has ended
    /// before the other starts; an ongoing entry (`end == nil`) is treated
    /// as extending to "now" for this comparison.
    static func rowsWithOverlaps(_ entries: [HistoryEntry]) -> [HistoryRow] {
        func overlaps(_ lhs: DateRange, _ rhs: DateRange) -> Bool {
            let lhsEnd = lhs.end ?? .distantFuture
            let rhsEnd = rhs.end ?? .distantFuture
            return lhs.start < rhsEnd && rhs.start < lhsEnd
        }
        return entries.map { entry in
            let overlaps = entries.contains { other in
                other.id != entry.id && overlaps(entry.range, other.range)
            }
            return HistoryRow(entry: entry, overlapsAnother: overlaps)
        }
    }
}
