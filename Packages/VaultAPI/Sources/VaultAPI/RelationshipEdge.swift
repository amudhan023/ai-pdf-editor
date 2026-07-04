import Foundation

/// Typed relationship kind between two `Person` profiles (PRD FR-2.3 names
/// spouse/child/parent/emergency contact explicitly; `.other` is the escape
/// hatch for relationships the catalog doesn't enumerate, in the same spirit
/// as `FieldPath.custom`).
public enum RelationshipKind: Sendable, Equatable {
    case spouse
    case child
    case parent
    case sibling
    case emergencyContact
    case other(String)
}

extension RelationshipKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case label
    }

    private enum Kind: String, Codable {
        case spouse, child, parent, sibling, emergencyContact, other
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .spouse: self = .spouse
        case .child: self = .child
        case .parent: self = .parent
        case .sibling: self = .sibling
        case .emergencyContact: self = .emergencyContact
        case .other: self = .other(try container.decode(String.self, forKey: .label))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .spouse: try container.encode(Kind.spouse, forKey: .kind)
        case .child: try container.encode(Kind.child, forKey: .kind)
        case .parent: try container.encode(Kind.parent, forKey: .kind)
        case .sibling: try container.encode(Kind.sibling, forKey: .kind)
        case .emergencyContact: try container.encode(Kind.emergencyContact, forKey: .kind)
        case .other(let label):
            try container.encode(Kind.other, forKey: .kind)
            try container.encode(label, forKey: .label)
        }
    }
}

/// A directed edge between two profiles, e.g. `from: priya, to: sam, kind:
/// .spouse`. Reciprocal relationships (spouse, sibling) are stored as a
/// single directed edge, not a mirrored pair — consumers that need the
/// inverse view query by either `from` or `to` (see `VaultClient.relationships(for:)`).
public struct RelationshipEdge: Sendable, Codable, Equatable {
    public let from: PersonID
    public let toPersonID: PersonID
    public let kind: RelationshipKind

    public init(from: PersonID, to toPersonID: PersonID, kind: RelationshipKind) {
        self.from = from
        self.toPersonID = toPersonID
        self.kind = kind
    }
}
