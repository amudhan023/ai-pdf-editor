import Foundation
import VaultAPI

/// One field as the detail view sees it: masked by default, revealed only
/// after a successful `TicketIssuing.issue(operation: .read, ...)` grant.
/// `revealedValue` is deliberately not persisted anywhere outside this
/// in-memory struct — re-navigating away and back re-masks.
public struct DisplayField: Identifiable, Equatable {
    public var id: FieldPath { path }
    public let path: FieldPath
    public let sensitivity: SensitivityTier
    public var revealedValue: FieldValue?

    public var isMasked: Bool { sensitivity == .sensitive && revealedValue == nil }
}

/// Section-organized field editing, custom fields, and history-list CRUD for
/// one person. Masking/reveal is real (goes through `TicketIssuing`, not a
/// UI-only blur) — an unrevealed sensitive field's plaintext never enters
/// this view model's state.
@MainActor
public final class ProfileDetailViewModel: ObservableObject {
    @Published public private(set) var fields: [FieldPath: DisplayField] = [:]
    @Published public private(set) var history: [HistoryCategory: [HistoryEntry]] = [:]
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var needsReauth = false

    public let personID: PersonID
    private let client: any VaultClient
    private let tickets: any TicketIssuing

    public init(personID: PersonID, client: any VaultClient, tickets: any TicketIssuing) {
        self.personID = personID
        self.client = client
        self.tickets = tickets
    }

    // MARK: - Fields

    /// Writes a field and records it locally as masked-if-sensitive — a
    /// write does not implicitly reveal (the user just typed the value, but
    /// re-displaying it after the fact still goes through the same reveal
    /// gate as any other sensitive field).
    public func writeField(path: FieldPath, value: FieldValue, sensitivity: SensitivityTier) async {
        errorMessage = nil
        needsReauth = false
        do {
            let ticket = try await tickets.issue(
                operation: .write, personID: personID, scopedPaths: [path], sensitivity: sensitivity
            )
            let field = ProfileField(personID: personID, path: path, value: value, sensitivity: sensitivity)
            try await client.writeField(field, ticket: ticket)
            fields[path] = DisplayField(path: path, sensitivity: sensitivity, revealedValue: sensitivity == .sensitive ? nil : value)
        } catch TicketIssuingError.requiresReauth {
            // Writing a .sensitive field is gated by the same freshness rule
            // as reading one (PolicyRules row 3 doesn't distinguish
            // operation) — surface the same re-auth affordance, not a flat
            // error the user can't act on.
            needsReauth = true
        } catch {
            errorMessage = "\(error)"
        }
    }

    public func deleteField(_ path: FieldPath) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .write, personID: personID, scopedPaths: [path], sensitivity: .standard)
            try await client.deleteField(path, for: personID, ticket: ticket)
            fields.removeValue(forKey: path)
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Reveals one field's plaintext. Requires a fresh `.read` grant for
    /// `.sensitive` fields (`PolicyRules`'s reauth gate); `needsReauth` lets
    /// the view offer a re-auth affordance instead of a flat error.
    public func reveal(_ path: FieldPath) async {
        errorMessage = nil
        needsReauth = false
        guard let existing = fields[path] else { return }
        do {
            let ticket = try await tickets.issue(
                operation: .read, personID: personID, scopedPaths: [path], sensitivity: existing.sensitivity
            )
            let read = try await client.readFields([path], for: personID, ticket: ticket)
            guard let value = read.first?.value else { return }
            fields[path] = DisplayField(path: path, sensitivity: existing.sensitivity, revealedValue: value)
            if existing.sensitivity == .sensitive {
                RevealAuditLog.revealed(path: path, personID: personID, sensitivity: existing.sensitivity)
            }
        } catch TicketIssuingError.requiresReauth {
            needsReauth = true
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Copies an already-revealed field's plaintext to the pasteboard,
    /// transient + auto-expiring (CLAUDE.md §7.4). Deliberately takes no
    /// path/lookup shortcut that could copy an unrevealed sensitive value —
    /// callers pass the plaintext the view is already displaying.
    public func copyRevealedValueToPasteboard(_ value: FieldValue) {
        let plaintext: String
        switch value {
        case .string(let bytes): plaintext = bytes.exposeAsPlaintext()
        case .date(let date): plaintext = ISO8601DateFormatter().string(from: date)
        case .number(let number): plaintext = String(number)
        case .enumeration(let raw): plaintext = raw
        case .list: plaintext = "" // lists aren't single-value pasteboard candidates in this UI
        }
        guard !plaintext.isEmpty else { return }
        TransientPasteboard.copy(plaintext)
    }

    /// Re-masks a field without deleting it — navigating away, closing the
    /// window, or an idle auto-lock should call this (CLAUDE.md §7.4:
    /// revealed values don't linger).
    public func mask(_ path: FieldPath) {
        guard let existing = fields[path] else { return }
        fields[path] = DisplayField(path: path, sensitivity: existing.sensitivity, revealedValue: nil)
    }

    // MARK: - History

    public func loadHistory(_ category: HistoryCategory) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .read, personID: personID, scopedPaths: [], sensitivity: .standard)
            history[category] = try await client.historyEntries(category: category, for: personID, ticket: ticket)
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Entries in the same category whose date ranges overlap `range` —
    /// surfaced by the view as a warning, not a hard block (e.g. two
    /// concurrent part-time employers is a legitimate real-world case).
    public func overlaps(with range: DateRange, category: HistoryCategory, excluding: UUID? = nil) -> [HistoryEntry] {
        (history[category] ?? []).filter { entry in
            entry.id != excluding && Self.rangesOverlap(entry.range, range)
        }
    }

    private static func rangesOverlap(_ first: DateRange, _ second: DateRange) -> Bool {
        let firstEnd = first.end ?? .distantFuture
        let secondEnd = second.end ?? .distantFuture
        return first.start < secondEnd && second.start < firstEnd
    }

    public func writeHistoryEntry(_ entry: HistoryEntry) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard)
            try await client.writeHistoryEntry(entry, ticket: ticket)
            await loadHistory(entry.category)
        } catch {
            errorMessage = "\(error)"
        }
    }

    public func deleteHistoryEntry(_ id: UUID, category: HistoryCategory) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard)
            try await client.deleteHistoryEntry(id, for: personID, ticket: ticket)
            await loadHistory(category)
        } catch {
            errorMessage = "\(error)"
        }
    }
}
