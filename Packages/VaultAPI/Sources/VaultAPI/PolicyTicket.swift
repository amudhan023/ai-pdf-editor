import Foundation

/// The operation a `PolicyTicket` grants. Deliberately coarser than full
/// CRUD (create/update/delete all collapse to `.write`) — PolicyKit mints a
/// ticket per user-visible decision ("allow this write"), not per SQL verb,
/// and a finer split isn't asked for by anything downstream yet. `.read` is
/// full disclosure; `.compareRead` is the narrower "does this match, without
/// revealing it" grant ARCHITECTURE.md §5.1 describes for ingestion conflict
/// detection.
public enum VaultOperation: String, Sendable, Codable, CaseIterable, Equatable {
    case read
    case write
    case compareRead
    case cryptoShred
}

/// An operation-scoped, time-boxed, field-path-scoped capability grant
/// (CLAUDE.md §3.3: "every privileged vault operation requires a
/// PolicyTicket from PolicyKit"). `signature` is an opaque payload —
/// minting and verifying it is PolicyKit's job; this package only defines
/// the shape and the structural (operation/person/path/expiry) checks any
/// `VaultClient` must enforce regardless of what the signature attests.
///
/// `scopedPaths` empty means "not path-scoped" (used by person-level
/// operations like `createPerson`/`cryptoShred`, which act on a whole
/// profile rather than named fields); a non-empty entry covers itself and
/// every path beneath it (`FieldPath.isPrefix(of:)`), so a ticket can grant
/// a whole section (e.g. `identity`) without enumerating every leaf.
public struct PolicyTicket: Sendable, Codable, Equatable {
    public let id: UUID
    public let operation: VaultOperation
    public let personID: PersonID
    public let scopedPaths: [FieldPath]
    public let issuedAt: Date
    public let expiresAt: Date
    public let signature: Data

    public init(
        id: UUID = UUID(),
        operation: VaultOperation,
        personID: PersonID,
        scopedPaths: [FieldPath] = [],
        issuedAt: Date,
        expiresAt: Date,
        signature: Data
    ) {
        self.id = id
        self.operation = operation
        self.personID = personID
        self.scopedPaths = scopedPaths
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.signature = signature
    }

    /// Whether `now` falls within the ticket's issued/expiry window. Half-open
    /// on the expiry end (`now < expiresAt`) so a ticket is unusable at the
    /// exact instant it expires, not one tick after.
    public func isTemporallyValid(at now: Date = Date()) -> Bool {
        now >= issuedAt && now < expiresAt
    }

    /// Whether this ticket's scope covers `path` — exact match or an
    /// ancestor section/path grant.
    public func covers(_ path: FieldPath) -> Bool {
        scopedPaths.contains { $0.isPrefix(of: path) }
    }
}
