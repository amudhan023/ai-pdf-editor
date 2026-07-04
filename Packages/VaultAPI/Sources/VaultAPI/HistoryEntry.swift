import Foundation

/// A start/optional-end date span. `end == nil` means "ongoing" (a current
/// address or current employer), not "unknown" — callers that need to
/// distinguish unknown-end from ongoing should model that at a higher layer.
public struct DateRange: Sendable, Codable, Equatable {
    public let start: Date
    public let end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public var isOngoing: Bool { end == nil }
}

/// Which history list an entry belongs to (PRD FR-2.1: "Contact (...
/// addresses incl. history w/ date ranges)", "Employment (history w/
/// dates...)", "Travel history", "Education"). First-class per
/// ARCHITECTURE.md §8.2 ("first-class, not JSON blobs, because
/// gap-detection queries need them") rather than folded into `ProfileField`.
public enum HistoryCategory: String, Sendable, Codable, CaseIterable, Equatable {
    case address
    case employer
    case education
    case travel
}

/// One field value attached to a `HistoryEntry` (e.g. an employer entry's
/// `employment.title` or `employment.employer.name`). A plain struct rather
/// than reusing `ProfileField` — a history entry's fields have no
/// independent `verifiedAt`/provenance of their own; they inherit the
/// entry's.
public struct HistoryFieldEntry: Sendable, Codable, Equatable {
    public let path: FieldPath
    public let value: FieldValue

    public init(path: FieldPath, value: FieldValue) {
        self.path = path
        self.value = value
    }
}

public struct HistoryEntry: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let personID: PersonID
    public let category: HistoryCategory
    public let range: DateRange
    public let fields: [HistoryFieldEntry]

    public init(
        id: UUID = UUID(),
        personID: PersonID,
        category: HistoryCategory,
        range: DateRange,
        fields: [HistoryFieldEntry] = []
    ) {
        self.id = id
        self.personID = personID
        self.category = category
        self.range = range
        self.fields = fields
    }
}
