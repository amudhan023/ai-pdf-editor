import XCTest
import CryptoKit
import VaultAPI
@testable import PolicyKit

final class TicketCryptoTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let key = SymmetricKey(size: .bits256)

    private func grantedRequest(sensitivity: SensitivityTier = .standard) -> PolicyRequest {
        PolicyRequest(
            operation: .read,
            sensitivity: sensitivity,
            authFreshness: AuthFreshness(lastAuthenticatedAt: now),
            sessionMode: .normal
        )
    }

    func testMintThenVerify_Succeeds() throws {
        let ticket = try TicketMinter.mint(
            request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now
        )
        let result = TicketVerifier.verify(ticket, signingKey: key, now: now.addingTimeInterval(30))
        if case .failure(let error) = result { XCTFail("expected success, got \(error)") }
    }

    func testMintRefusesWhenNotGranted() {
        // Ephemeral write is always denied by the rules - minting must refuse, not mint anyway.
        let req = PolicyRequest(
            operation: .write, sensitivity: .standard,
            authFreshness: AuthFreshness(lastAuthenticatedAt: now), sessionMode: .ephemeral
        )
        XCTAssertThrowsError(try TicketMinter.mint(request: req, personID: PersonID(), ttl: 60, signingKey: key, now: now)) { error in
            XCTAssertEqual(error as? TicketMintingError, .notGranted(.deny))
        }
    }

    func testExpiredTicket_FailsVerification() throws {
        let ticket = try TicketMinter.mint(request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now)
        let result = TicketVerifier.verify(ticket, signingKey: key, now: now.addingTimeInterval(61))
        guard case .failure(.expired) = result else { return XCTFail("expected .expired, got \(result)") }
    }

    func testTamperedSignature_FailsVerification() throws {
        let ticket = try TicketMinter.mint(request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now)
        var tamperedBytes = ticket.signature
        tamperedBytes[0] ^= 0xFF
        let tampered = PolicyTicket(
            id: ticket.id, operation: ticket.operation, personID: ticket.personID,
            scopedPaths: ticket.scopedPaths, issuedAt: ticket.issuedAt, expiresAt: ticket.expiresAt,
            signature: tamperedBytes
        )
        let result = TicketVerifier.verify(tampered, signingKey: key, now: now)
        guard case .failure(.invalidSignature) = result else { return XCTFail("expected .invalidSignature, got \(result)") }
    }

    func testTamperedClaim_FailsVerification() throws {
        // Same signature, but a claim (personID) changed after minting - the
        // HMAC won't match the altered payload.
        let ticket = try TicketMinter.mint(request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now)
        let tampered = PolicyTicket(
            id: ticket.id, operation: ticket.operation, personID: PersonID(), // different person
            scopedPaths: ticket.scopedPaths, issuedAt: ticket.issuedAt, expiresAt: ticket.expiresAt,
            signature: ticket.signature
        )
        let result = TicketVerifier.verify(tampered, signingKey: key, now: now)
        guard case .failure(.invalidSignature) = result else { return XCTFail("expected .invalidSignature, got \(result)") }
    }

    func testWrongSigningKey_FailsVerification() throws {
        let ticket = try TicketMinter.mint(request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now)
        let wrongKey = SymmetricKey(size: .bits256)
        let result = TicketVerifier.verify(ticket, signingKey: wrongKey, now: now)
        guard case .failure(.invalidSignature) = result else { return XCTFail("expected .invalidSignature, got \(result)") }
    }

    func testReplayedTicket_RejectedBySecondConsume() async throws {
        let ticket = try TicketMinter.mint(request: grantedRequest(), personID: PersonID(), ttl: 60, signingKey: key, now: now)
        let guardActor = ReplayGuard()
        let first = await guardActor.consume(ticket.id)
        let second = await guardActor.consume(ticket.id)
        XCTAssertTrue(first, "first consume of a fresh ticket ID must succeed")
        XCTAssertFalse(second, "second consume of the same ticket ID must be rejected as a replay")
    }

    func testDifferentTicketIDs_BothConsumeIndependently() async throws {
        let guardActor = ReplayGuard()
        let firstConsumed = await guardActor.consume(UUID())
        let secondConsumed = await guardActor.consume(UUID())
        XCTAssertTrue(firstConsumed)
        XCTAssertTrue(secondConsumed)
    }
}
