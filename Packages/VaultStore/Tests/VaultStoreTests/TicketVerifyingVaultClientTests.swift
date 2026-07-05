import XCTest
import CryptoKit
import VaultAPI
import PolicyKit
@testable import VaultStore

/// Negative-path tests for the decorator that adds real HMAC signature
/// verification + replay rejection in front of a `VaultClient`
/// (CLAUDE.md §9's "ticket-less call rejected... tampered pack refused...
/// replay" security-relevant negative tests).
final class TicketVerifyingVaultClientTests: XCTestCase {
    private let signingKey = SymmetricKey(size: .bits256)

    private func mintValidTicket(person: PersonID) throws -> PolicyTicket {
        try TicketMinter.mint(
            request: PolicyRequest(
                operation: .write, sensitivity: .standard,
                authFreshness: AuthFreshness(lastAuthenticatedAt: Date()), sessionMode: .normal
            ),
            personID: person, ttl: 300, signingKey: signingKey
        )
    }

    func testValidSignedTicketPassesThrough() async throws {
        let inner = FakeVaultClient()
        let decorated = TicketVerifyingVaultClient(wrapping: inner, signingKey: signingKey)
        let person = Person(kind: .person, displayName: "Priya Shah")
        let ticket = try mintValidTicket(person: person.id)

        let created = try await decorated.createPerson(person, ticket: ticket)
        XCTAssertEqual(created.id, person.id)
    }

    func testTamperedSignatureIsRejected() async throws {
        let inner = FakeVaultClient()
        let decorated = TicketVerifyingVaultClient(wrapping: inner, signingKey: signingKey)
        let person = Person(kind: .person, displayName: "Priya Shah")
        var ticket = try mintValidTicket(person: person.id)
        ticket = PolicyTicket(
            id: ticket.id, operation: ticket.operation, personID: ticket.personID,
            scopedPaths: ticket.scopedPaths, issuedAt: ticket.issuedAt, expiresAt: ticket.expiresAt,
            signature: Data([0xFF, 0x00, 0x01])
        )

        do {
            _ = try await decorated.createPerson(person, ticket: ticket)
            XCTFail("a ticket with a tampered signature must be rejected")
        } catch {
            XCTAssertEqual(error as? TicketVerificationFailure, .invalidSignature)
        }
    }

    func testReplayedTicketIsRejectedOnSecondUse() async throws {
        let inner = FakeVaultClient()
        let decorated = TicketVerifyingVaultClient(wrapping: inner, signingKey: signingKey)
        let person = Person(kind: .person, displayName: "Priya Shah")
        let ticket = try mintValidTicket(person: person.id)

        _ = try await decorated.createPerson(person, ticket: ticket)
        do {
            _ = try await decorated.deletePerson(person.id, ticket: ticket)
            XCTFail("reusing the same ticket ID must be rejected as a replay")
        } catch {
            XCTAssertEqual(error as? TicketVerificationFailure, .replayed)
        }
    }

    func testExpiredTicketIsRejected() async throws {
        let inner = FakeVaultClient()
        let decorated = TicketVerifyingVaultClient(wrapping: inner, signingKey: signingKey)
        let person = Person(kind: .person, displayName: "Priya Shah")
        let ticket = try TicketMinter.mint(
            request: PolicyRequest(
                operation: .write, sensitivity: .standard,
                authFreshness: AuthFreshness(lastAuthenticatedAt: Date()), sessionMode: .normal
            ),
            personID: person.id, ttl: -1, signingKey: signingKey
        )

        do {
            _ = try await decorated.createPerson(person, ticket: ticket)
            XCTFail("an expired ticket must be rejected")
        } catch {
            XCTAssertEqual(error as? TicketVerificationFailure, .expired)
        }
    }

    func testWrongSigningKeyIsRejected() async throws {
        let inner = FakeVaultClient()
        let decorated = TicketVerifyingVaultClient(wrapping: inner, signingKey: SymmetricKey(size: .bits256))
        let person = Person(kind: .person, displayName: "Priya Shah")
        let ticket = try mintValidTicket(person: person.id)

        do {
            _ = try await decorated.createPerson(person, ticket: ticket)
            XCTFail("a ticket signed with a different key must be rejected")
        } catch {
            XCTAssertEqual(error as? TicketVerificationFailure, .invalidSignature)
        }
    }
}
