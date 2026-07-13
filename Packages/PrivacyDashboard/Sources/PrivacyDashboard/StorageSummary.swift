import Foundation
import VaultAPI

/// Per-section presence count for one profile — "what's stored" (PRD
/// FR-5.2), never the values themselves. `sectionCounts` only lists
/// sections `StorageSummaryService` actually queried
/// (`VaultFieldCatalog.leafPaths()`'s keys); a section absent from the dict
/// was not queried, not "zero."
public struct PersonStorageSummary: Sendable, Equatable {
    public let personID: PersonID
    public let displayName: String
    public let sectionCounts: [FieldSection: Int]
    public let totalFieldsPresent: Int

    public init(personID: PersonID, displayName: String, sectionCounts: [FieldSection: Int]) {
        self.personID = personID
        self.displayName = displayName
        self.sectionCounts = sectionCounts
        self.totalFieldsPresent = sectionCounts.values.reduce(0, +)
    }
}

/// Builds `PersonStorageSummary`s from `VaultClient.compareRead` — the
/// "count-only compare-grant" this task's Background section calls for, so
/// the dashboard can show field counts without ever holding a value.
///
/// Callers provide the `Person` list (this package has no way to enumerate
/// persons itself — see this package's CLAUDE.md "Known Gaps") and a single
/// `PolicyTicket` whose `scopedPaths` covers every `FieldSection` this
/// service queries (a bare per-section path, e.g. `identity`, covers every
/// leaf beneath it via `FieldPath.isPrefix(of:)`) — minting that broad a
/// compare-only grant is the composition root's job, not this service's.
public struct StorageSummaryService: Sendable {
    private let client: VaultClient

    public init(client: VaultClient) {
        self.client = client
    }

    public func summarize(_ person: Person, ticket: PolicyTicket) async throws -> PersonStorageSummary {
        let catalog = try VaultFieldCatalog.leafPaths()
        var counts: [FieldSection: Int] = [:]
        for (section, paths) in catalog {
            let summaries = try await client.compareRead(paths, for: person.id, ticket: ticket)
            counts[section] = summaries.filter(\.isPresent).count
        }
        return PersonStorageSummary(personID: person.id, displayName: person.displayName, sectionCounts: counts)
    }

    /// Summarizes multiple profiles. `ticket(for:)` mints (or looks up) a
    /// compare-read ticket scoped to that specific person — a single ticket
    /// can't cover more than one `personID` (`PolicyTicket.personID` is
    /// checked per call), so multi-person summaries need one grant each.
    public func summarize(
        _ persons: [Person],
        ticket: (PersonID) -> PolicyTicket
    ) async throws -> [PersonStorageSummary] {
        var out: [PersonStorageSummary] = []
        for person in persons {
            out.append(try await summarize(person, ticket: ticket(person.id)))
        }
        return out
    }
}
