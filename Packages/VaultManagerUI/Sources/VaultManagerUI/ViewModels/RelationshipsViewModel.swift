import Foundation
import VaultAPI

/// Drives the relationships editor for one profile (PRD FR-2.3: "add
/// relationships (spouse, child, parent, emergency contact)"). Scoped to a
/// single `personID` — the sidebar creates one of these per selected
/// profile rather than one shared instance for the whole roster.
@MainActor
public final class RelationshipsViewModel: ObservableObject {
    @Published public private(set) var edges: [RelationshipEdge] = []
    @Published public private(set) var lastError: VaultError?

    public let personID: PersonID
    private let client: any VaultClient
    private let tickets: any VaultTicketProviding

    public init(personID: PersonID, client: any VaultClient, tickets: any VaultTicketProviding) {
        self.personID = personID
        self.client = client
        self.tickets = tickets
    }

    public func refresh() async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .read, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            edges = try await client.relationships(for: personID, ticket: ticket)
        } catch let error as VaultError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func addRelationship(to other: PersonID, kind: RelationshipKind) async {
        let edge = RelationshipEdge(from: personID, to: other, kind: kind)
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            try await client.addRelationship(edge, ticket: ticket)
            edges.append(edge)
        } catch let error as VaultError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func removeRelationship(_ edge: RelationshipEdge) async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [], sensitivity: .standard
            )
            try await client.removeRelationship(edge, ticket: ticket)
            edges.removeAll { $0 == edge }
        } catch let error as VaultError {
            lastError = error
        } catch {
            lastError = nil
        }
    }
}
