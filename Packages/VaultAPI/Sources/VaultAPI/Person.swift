import Foundation

/// Opaque identity for a `Person` row. A distinct type (not a bare `UUID`)
/// so person/document/history identifiers can't be accidentally swapped at
/// call sites — same rationale as `PDFEngineAPI`'s `DocumentHandle`.
public struct PersonID: Sendable, Hashable, Codable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

/// A profile is either an individual or an organization/business (PRD
/// FR-2.3: "one organization/business profile type"). Both share the same
/// field/section/provenance machinery; only `kind` distinguishes them.
public enum PersonKind: String, Sendable, Codable, CaseIterable, Equatable {
    case person
    case organization
}

public struct Person: Sendable, Codable, Equatable, Identifiable {
    public let id: PersonID
    public let kind: PersonKind
    public let displayName: String

    public init(id: PersonID = PersonID(), kind: PersonKind, displayName: String) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
    }
}
