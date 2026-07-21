import Foundation
import PolicyKit

/// The "how recently did the user prove presence" signal `FakeTicketIssuer`
/// feeds into `PolicyRules.decide`, and `VaultUnlockViewModel` updates on
/// unlock/reauth. Split from `TicketIssuing` because both it and the unlock
/// flow need to read/write the same freshness timestamp.
public protocol AuthFreshnessClock: Sendable {
    func currentFreshness() async -> AuthFreshness
    func noteAuthenticated(at date: Date) async
}

public actor InMemoryAuthFreshnessClock: AuthFreshnessClock {
    private var lastAuthenticatedAt: Date

    /// Defaults to `.distantPast` so a freshly-constructed clock reads as
    /// stale — a view model must observe a real unlock/reauth event before
    /// any sensitive-tier grant is possible, never "fresh by default."
    public init(lastAuthenticatedAt: Date = .distantPast) {
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }

    public func currentFreshness() async -> AuthFreshness {
        AuthFreshness(lastAuthenticatedAt: lastAuthenticatedAt)
    }

    public func noteAuthenticated(at date: Date) async {
        lastAuthenticatedAt = date
    }
}
