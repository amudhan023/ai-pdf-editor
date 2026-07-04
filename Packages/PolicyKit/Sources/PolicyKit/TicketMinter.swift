import Foundation
import CryptoKit
import VaultAPI

/// Minting refused because the policy decision for the requested operation
/// wasn't `.grant`. Carries the actual decision so a caller can distinguish
/// "needs reauth" from "denied outright" without re-running the rules.
public enum TicketMintingError: Error, Sendable, Equatable {
    case notGranted(PolicyDecision)
}

/// Mints signed `PolicyTicket`s. The signing key is always supplied by the
/// caller — PolicyKit has zero I/O and never fetches or stores key material
/// itself (that's Keychain/Platform's job); this keeps minting a pure
/// function of its arguments plus the key.
public enum TicketMinter {
    public static func mint(
        request: PolicyRequest,
        personID: PersonID,
        scopedPaths: [FieldPath] = [],
        ttl: TimeInterval,
        signingKey: SymmetricKey,
        now: Date = Date(),
        authFreshnessWindow: TimeInterval = PolicyRules.defaultAuthFreshnessWindow
    ) throws -> PolicyTicket {
        let decision = PolicyRules.decide(request, now: now, authFreshnessWindow: authFreshnessWindow)
        guard decision == .grant else { throw TicketMintingError.notGranted(decision) }

        let id = UUID()
        let expiresAt = now.addingTimeInterval(ttl)
        let claims = TicketClaims(
            id: id, operation: request.operation, personID: personID,
            scopedPaths: scopedPaths, issuedAt: now, expiresAt: expiresAt
        )
        let signature = try sign(claims, key: signingKey)

        return PolicyTicket(
            id: id, operation: request.operation, personID: personID,
            scopedPaths: scopedPaths, issuedAt: now, expiresAt: expiresAt,
            signature: signature
        )
    }

    static func sign(_ claims: TicketClaims, key: SymmetricKey) throws -> Data {
        let payload = try claims.canonicalPayload()
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(mac)
    }
}
