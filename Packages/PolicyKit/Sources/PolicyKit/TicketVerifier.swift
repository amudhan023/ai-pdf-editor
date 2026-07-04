import Foundation
import CryptoKit
import VaultAPI

public enum TicketVerificationError: Error, Sendable, Equatable {
    case expired
    case invalidSignature
    case replayed
}

/// Verifies a `PolicyTicket`'s structural validity (expiry) and cryptographic
/// integrity (HMAC match, constant-time via CryptoKit's own comparison).
/// Replay rejection is a separate step (`ReplayGuard`) since it requires
/// state across calls — everything in this type stays a pure function of
/// `(ticket, signingKey, now)`.
public enum TicketVerifier {
    public static func verify(
        _ ticket: PolicyTicket,
        signingKey: SymmetricKey,
        now: Date = Date()
    ) -> Result<Void, TicketVerificationError> {
        guard ticket.isTemporallyValid(at: now) else { return .failure(.expired) }

        let claims = TicketClaims(ticket: ticket)
        guard let payload = try? claims.canonicalPayload() else { return .failure(.invalidSignature) }

        guard HMAC<SHA256>.isValidAuthenticationCode(ticket.signature, authenticating: payload, using: signingKey) else {
            return .failure(.invalidSignature)
        }
        return .success(())
    }
}
