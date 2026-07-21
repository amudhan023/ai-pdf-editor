import Foundation
import VaultAPI
import PolicyKit

/// A reveal/write attempt was refused by policy. Distinct from `.deny` so UI
/// can offer a re-auth affordance instead of a flat error (mirrors
/// `PolicyDecision.requireReauth`'s own rationale).
public enum TicketIssuingError: Error, Sendable, Equatable {
    case requiresReauth
    case denied
}

/// Mints a `PolicyTicket` for a UI-initiated vault operation. Abstracted
/// behind a protocol because this package cannot import CryptoKit (see
/// `Scripts/import-allowlist.txt`) — real signing needs a `SymmetricKey`
/// only Platform/Keychain may hold. Production wiring (a `TicketIssuing`
/// backed by `PolicyKit.TicketMinter` + a Keychain-sourced key) is the
/// composition root's job, not this package's.
public protocol TicketIssuing: Sendable {
    func issue(
        operation: VaultOperation,
        personID: PersonID,
        scopedPaths: [FieldPath],
        sensitivity: SensitivityTier
    ) async throws -> PolicyTicket
}

/// Runs the real `PolicyRules.decide` table, then mints a ticket with an
/// empty signature on `.grant`. Safe only against `FakeVaultClient`, which
/// documents that it "trusts `PolicyTicket.signature` unconditionally" —
/// verification is PolicyKit's job, not `VaultClient`'s. Not safe against a
/// real signature-checking implementation; that pairing is a future
/// `[INTEGRATION]` task, not this one.
public actor FakeTicketIssuer: TicketIssuing {
    private let sessionMode: SessionMode
    private let authFreshnessClock: AuthFreshnessClock
    private let ttl: TimeInterval

    public init(
        sessionMode: SessionMode = .normal,
        authFreshnessClock: AuthFreshnessClock,
        ttl: TimeInterval = 5 * 60
    ) {
        self.sessionMode = sessionMode
        self.authFreshnessClock = authFreshnessClock
        self.ttl = ttl
    }

    public func issue(
        operation: VaultOperation,
        personID: PersonID,
        scopedPaths: [FieldPath],
        sensitivity: SensitivityTier
    ) async throws -> PolicyTicket {
        let now = Date()
        let request = PolicyRequest(
            operation: operation,
            sensitivity: sensitivity,
            authFreshness: await authFreshnessClock.currentFreshness(),
            sessionMode: sessionMode
        )
        switch PolicyRules.decide(request, now: now) {
        case .deny:
            throw TicketIssuingError.denied
        case .requireReauth:
            throw TicketIssuingError.requiresReauth
        case .grant:
            return PolicyTicket(
                operation: operation,
                personID: personID,
                scopedPaths: scopedPaths,
                issuedAt: now,
                expiresAt: now.addingTimeInterval(ttl),
                signature: Data()
            )
        }
    }
}
