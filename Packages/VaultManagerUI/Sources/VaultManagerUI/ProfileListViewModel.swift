import Foundation
import VaultAPI

/// The profile sidebar: person/org list, create, delete, relationships
/// between two profiles. Every write goes through `TicketIssuing` — no
/// direct `PolicyTicket` construction here (CLAUDE.md §3.3's "no bypass
/// path").
@MainActor
public final class ProfileListViewModel: ObservableObject {
    @Published public private(set) var persons: [Person] = []
    @Published public private(set) var relationships: [PersonID: [RelationshipEdge]] = [:]
    @Published public private(set) var errorMessage: String?
    @Published public var selectedPersonID: PersonID?

    private let client: any VaultClient
    private let tickets: any TicketIssuing

    public init(client: any VaultClient, tickets: any TicketIssuing) {
        self.client = client
        self.tickets = tickets
    }

    /// Refreshes relationship edges for every person already known to this
    /// view model. Does **not** discover new persons: `VaultClient` (a
    /// frozen seam, ADR-007) has no "list all persons" operation, only
    /// per-ID `person(_:ticket:)` — `persons` here is this session's own
    /// record of who it created/loaded, not a live query. A real app needs
    /// an ID index (e.g. bookmarked `PersonID`s) from somewhere outside this
    /// package to repopulate `persons` across launches; flagged as a
    /// VaultAPI gap in this task's Handoff, not fixed here (frozen seam).
    public func refreshRelationships() async {
        errorMessage = nil
        do {
            var loaded: [PersonID: [RelationshipEdge]] = [:]
            for person in persons {
                let ticket = try await tickets.issue(
                    operation: .read, personID: person.id, scopedPaths: [], sensitivity: .standard
                )
                loaded[person.id] = try await client.relationships(for: person.id, ticket: ticket)
            }
            relationships = loaded
        } catch {
            errorMessage = "\(error)"
        }
    }

    @discardableResult
    public func createPerson(kind: PersonKind, displayName: String) async -> Person? {
        errorMessage = nil
        let person = Person(kind: kind, displayName: displayName)
        do {
            let ticket = try await tickets.issue(
                operation: .write, personID: person.id, scopedPaths: [], sensitivity: .standard
            )
            let created = try await client.createPerson(person, ticket: ticket)
            persons.append(created)
            return created
        } catch {
            errorMessage = "\(error)"
            return nil
        }
    }

    public func deletePerson(_ id: PersonID) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .write, personID: id, scopedPaths: [], sensitivity: .standard)
            try await client.deletePerson(id, ticket: ticket)
            persons.removeAll { $0.id == id }
            relationships.removeValue(forKey: id)
            if selectedPersonID == id { selectedPersonID = nil }
        } catch {
            errorMessage = "\(error)"
        }
    }

    public func addRelationship(from: PersonID, to: PersonID, kind: RelationshipKind) async {
        errorMessage = nil
        do {
            let ticket = try await tickets.issue(operation: .write, personID: from, scopedPaths: [], sensitivity: .standard)
            let edge = RelationshipEdge(from: from, to: to, kind: kind)
            try await client.addRelationship(edge, ticket: ticket)
            relationships[from, default: []].append(edge)
        } catch {
            errorMessage = "\(error)"
        }
    }
}
