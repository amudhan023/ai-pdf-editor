import Foundation
import GRDB
import VaultAPI

/// Storage-layer row shapes and their conversions to/from the `VaultAPI`
/// domain types. Field/history values and provenance are stored as JSON
/// BLOBs (all three types are already `Codable` in `VaultAPI`) rather than
/// broken into columns — SQLCipher's full-database encryption is the
/// ciphertext-at-rest guarantee here; per-column ciphertext is an explicit,
/// documented future upgrade (ARCHITECTURE.md §8.2), not required now.
enum RecordCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
}

struct PersonRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "person"
    var id: String
    var kind: String
    var displayName: String

    init(_ person: Person) {
        id = person.id.value.uuidString
        kind = person.kind.rawValue
        displayName = person.displayName
    }

    func asDomain() throws -> Person {
        guard let uuid = UUID(uuidString: id), let kind = PersonKind(rawValue: kind) else {
            throw VaultStoreDecodingError.corruptRow(table: Self.databaseTableName)
        }
        return Person(id: PersonID(uuid), kind: kind, displayName: displayName)
    }
}

struct ProfileFieldRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profileField"
    var personID: String
    var path: String
    var valueData: Data
    var sensitivity: String
    var aliasesData: Data
    var verifiedAt: Date?
    var provenanceData: Data

    init(_ field: ProfileField) throws {
        personID = field.personID.value.uuidString
        path = field.path.description
        valueData = try RecordCoding.encoder.encode(field.value)
        sensitivity = field.sensitivity.rawValue
        aliasesData = try RecordCoding.encoder.encode(field.aliases)
        verifiedAt = field.verifiedAt
        provenanceData = try RecordCoding.encoder.encode(field.provenance)
    }

    func asDomain() throws -> ProfileField {
        guard let uuid = UUID(uuidString: personID), let sensitivity = SensitivityTier(rawValue: sensitivity) else {
            throw VaultStoreDecodingError.corruptRow(table: Self.databaseTableName)
        }
        return ProfileField(
            personID: PersonID(uuid),
            path: try FieldPath(validating: path),
            value: try RecordCoding.decoder.decode(FieldValue.self, from: valueData),
            sensitivity: sensitivity,
            aliases: try RecordCoding.decoder.decode([String].self, from: aliasesData),
            verifiedAt: verifiedAt,
            provenance: try RecordCoding.decoder.decode(Provenance.self, from: provenanceData)
        )
    }
}

struct HistoryEntryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "historyEntry"
    var id: String
    var personID: String
    var category: String
    var rangeStart: Date
    var rangeEnd: Date?

    init(_ entry: HistoryEntry) {
        id = entry.id.uuidString
        personID = entry.personID.value.uuidString
        category = entry.category.rawValue
        rangeStart = entry.range.start
        rangeEnd = entry.range.end
    }

    func asDomain(fields: [HistoryFieldEntry]) throws -> HistoryEntry {
        guard let entryID = UUID(uuidString: id), let personUUID = UUID(uuidString: personID),
              let category = HistoryCategory(rawValue: category) else {
            throw VaultStoreDecodingError.corruptRow(table: Self.databaseTableName)
        }
        return HistoryEntry(
            id: entryID,
            personID: PersonID(personUUID),
            category: category,
            range: DateRange(start: rangeStart, end: rangeEnd),
            fields: fields
        )
    }
}

struct HistoryFieldEntryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "historyFieldEntry"
    var historyEntryID: String
    var path: String
    var valueData: Data

    init(historyEntryID: String, field: HistoryFieldEntry) throws {
        self.historyEntryID = historyEntryID
        path = field.path.description
        valueData = try RecordCoding.encoder.encode(field.value)
    }

    func asDomain() throws -> HistoryFieldEntry {
        HistoryFieldEntry(
            path: try FieldPath(validating: path),
            value: try RecordCoding.decoder.decode(FieldValue.self, from: valueData)
        )
    }
}

struct RelationshipEdgeRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "relationshipEdge"
    var rowID: Int64?
    var fromPersonID: String
    var toPersonID: String
    var kindTag: String
    var kindLabel: String?

    init(_ edge: RelationshipEdge) {
        fromPersonID = edge.from.value.uuidString
        toPersonID = edge.toPersonID.value.uuidString
        switch edge.kind {
        case .spouse: kindTag = "spouse"; kindLabel = nil
        case .child: kindTag = "child"; kindLabel = nil
        case .parent: kindTag = "parent"; kindLabel = nil
        case .sibling: kindTag = "sibling"; kindLabel = nil
        case .emergencyContact: kindTag = "emergencyContact"; kindLabel = nil
        case .other(let label): kindTag = "other"; kindLabel = label
        }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        rowID = inserted.rowID
    }

    func asDomain() throws -> RelationshipEdge {
        guard let fromUUID = UUID(uuidString: fromPersonID), let toUUID = UUID(uuidString: toPersonID) else {
            throw VaultStoreDecodingError.corruptRow(table: Self.databaseTableName)
        }
        let kind: RelationshipKind
        switch kindTag {
        case "spouse": kind = .spouse
        case "child": kind = .child
        case "parent": kind = .parent
        case "sibling": kind = .sibling
        case "emergencyContact": kind = .emergencyContact
        case "other": kind = .other(kindLabel ?? "")
        default: throw VaultStoreDecodingError.corruptRow(table: Self.databaseTableName)
        }
        return RelationshipEdge(from: PersonID(fromUUID), to: PersonID(toUUID), kind: kind)
    }
}

/// Typed error for storage-layer decode failures — distinct from `VaultError`
/// (a `VaultAPI` frozen-seam type) since "the row in our own DB is corrupt"
/// isn't a contract `VaultClient` callers need to plan for, it's an
/// implementation-internal integrity fault.
enum VaultStoreDecodingError: Error, Sendable, Equatable {
    case corruptRow(table: String)
}
