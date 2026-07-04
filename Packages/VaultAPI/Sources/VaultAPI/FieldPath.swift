import Foundation

/// The fixed top-level sections a `FieldPath` may belong to (PRD FR-2.1).
/// `.custom` is the extension escape hatch for user-defined fields/sections
/// (FR-2.1's "Custom fields/sections") — see `FieldPath.custom(_:)`. This is
/// the type-level enforcement of CLAUDE.md §5's "never invent paths ad hoc":
/// a path whose first segment isn't one of these cases fails to parse.
public enum FieldSection: String, Sendable, Codable, CaseIterable, Equatable {
    case identity
    case contact
    case employment
    case education
    case family
    case financial
    case health
    case licenses
    case travel
    case custom
}

/// A typed, dot-separated, lowercase vault field path (e.g.
/// `identity.passport.number`). The canonical catalog of concrete paths
/// lives in `docs/specs/vault-schema.md` — this type only enforces the
/// *shape* every path must have (known section, lowercase/digits/underscore
/// segments), not the specific catalog, so the doc stays the one owner of
/// "what fields exist" (CLAUDE.md §10).
public struct FieldPath: Sendable, Hashable, CustomStringConvertible {
    public let section: FieldSection
    public let segments: [String]

    public var description: String { segments.joined(separator: ".") }

    /// Parses and validates a raw dot-separated path. Throws rather than
    /// crashing or silently truncating — CLAUDE.md §15's "total function"
    /// rule for input-reachable paths.
    public init(validating raw: String) throws {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let first = parts.first, let section = FieldSection(rawValue: first) else {
            throw VaultError.invalidFieldPath(raw)
        }
        for part in parts {
            guard FieldPath.isValidSegment(part) else { throw VaultError.invalidFieldPath(raw) }
        }
        self.section = section
        self.segments = parts
    }

    private init(section: FieldSection, segments: [String]) {
        self.section = section
        self.segments = segments
    }

    /// Builds a path under the `custom` section, the mechanism FR-2.1's
    /// "custom fields/sections" is expressed through: `custom(["notes"])`
    /// yields `custom.notes`, `custom(["boat", "hull_id"])` yields
    /// `custom.boat.hull_id`. Still validated — custom does not mean
    /// unchecked.
    public static func custom(_ trailing: [String]) throws -> FieldPath {
        guard !trailing.isEmpty, trailing.allSatisfy(isValidSegment) else {
            throw VaultError.invalidFieldPath((["custom"] + trailing).joined(separator: "."))
        }
        return FieldPath(section: .custom, segments: [FieldSection.custom.rawValue] + trailing)
    }

    /// True if `self` names an ancestor section/path of (or is equal to)
    /// `other` — e.g. `identity` is a prefix of `identity.passport.number`,
    /// as is `identity.passport`. Used by `PolicyTicket` to grant a whole
    /// section without enumerating every leaf path.
    public func isPrefix(of other: FieldPath) -> Bool {
        guard segments.count <= other.segments.count else { return false }
        return zip(segments, other.segments).allSatisfy(==)
    }

    private static let allowedScalars = CharacterSet.lowercaseLetters
        .union(.decimalDigits)
        .union(CharacterSet(charactersIn: "_"))

    private static func isValidSegment(_ segment: String) -> Bool {
        guard !segment.isEmpty else { return false }
        return segment.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }
}

extension FieldPath: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        try self.init(validating: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
