import Foundation
import VaultAPI
import os

/// Drives the profile sidebar: the person/organization list plus create
/// and delete. Relationship editing is `RelationshipsViewModel`'s job (a
/// person-pair concept, not a list-of-persons one).
@MainActor
public final class ProfileListViewModel: ObservableObject {
    @Published public private(set) var people: [Person] = []
    @Published public private(set) var lastError: VaultError?

    private let client: any VaultClient
    private let tickets: any VaultTicketProviding
    private let logger = Logger(subsystem: "com.vaultform.app", category: "VaultManagerUI")

    public init(client: any VaultClient, tickets: any VaultTicketProviding) {
        self.client = client
        self.tickets = tickets
    }

    /// Loads the roster from `known` — `VaultClient` has no "list all
    /// persons" method (each `Person` is fetched by its own `PersonID`), so
    /// the sidebar's set of known IDs comes from whatever session/onboarding
    /// state already tracked them; this view model only refreshes each row.
    public func refresh(known ids: [PersonID]) async {
        var refreshed: [Person] = []
        for id in ids {
            do {
                let ticket = try await tickets.requestTicket(
                    operation: .read, personID: id, scopedPaths: [], sensitivity: .standard
                )
                refreshed.append(try await client.person(id, ticket: ticket))
            } catch let error as VaultError {
                lastError = error
                logger.error("profile refresh failed: \(String(describing: error.recoverability), privacy: .public)")
            } catch {
                logger.error("profile refresh failed: ticket request error")
            }
        }
        people = refreshed
    }

    @discardableResult
    public func createProfile(kind: PersonKind, displayName: String) async -> Person? {
        let person = Person(kind: kind, displayName: displayName)
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: person.id, scopedPaths: [], sensitivity: .standard
            )
            let created = try await client.createPerson(person, ticket: ticket)
            people.append(created)
            return created
        } catch let error as VaultError {
            lastError = error
            return nil
        } catch {
            logger.error("createProfile failed: ticket request error")
            return nil
        }
    }

    public func deleteProfile(_ id: PersonID) async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: id, scopedPaths: [], sensitivity: .standard
            )
            try await client.deletePerson(id, ticket: ticket)
            people.removeAll { $0.id == id }
        } catch let error as VaultError {
            lastError = error
        } catch {
            logger.error("deleteProfile failed: ticket request error")
        }
    }
}
