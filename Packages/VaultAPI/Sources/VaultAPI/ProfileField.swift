import Foundation

/// One vault field on a profile (ARCHITECTURE.md §8.2's `sections -> fields`
/// row: id, person_id, path, type, value, sensitivity, aliases, verified_at
/// — `value_ciphertext` is a `VaultStore` storage concern, not modeled here).
/// `id` is scoped to a single person's field set, the same pattern
/// `PDFEngineAPI.FormField` uses for field names scoped to one document.
public struct ProfileField: Sendable, Codable, Equatable, Identifiable {
    public var id: FieldPath { path }

    public let personID: PersonID
    public let path: FieldPath
    public let value: FieldValue
    public let sensitivity: SensitivityTier
    public let aliases: [String]
    public let verifiedAt: Date?
    public let provenance: Provenance

    public init(
        personID: PersonID,
        path: FieldPath,
        value: FieldValue,
        sensitivity: SensitivityTier = .standard,
        aliases: [String] = [],
        verifiedAt: Date? = nil,
        provenance: Provenance = .manual
    ) {
        self.personID = personID
        self.path = path
        self.value = value
        self.sensitivity = sensitivity
        self.aliases = aliases
        self.verifiedAt = verifiedAt
        self.provenance = provenance
    }
}
