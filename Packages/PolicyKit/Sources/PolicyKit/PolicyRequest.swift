import Foundation
import VaultAPI

/// How long ago the user last authenticated, expressed as a fixed instant
/// rather than a duration so rule evaluation stays a pure function of
/// (`request`, `now`) — no hidden clock reads inside a rule.
public struct AuthFreshness: Sendable, Codable, Equatable {
    public let lastAuthenticatedAt: Date

    public init(lastAuthenticatedAt: Date) {
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }

    public func isFresh(at now: Date, within window: TimeInterval) -> Bool {
        now.timeIntervalSince(lastAuthenticatedAt) <= window
    }
}

/// Ephemeral mode denies anything that would persist data (PRD's "ephemeral
/// session" concept — e.g. a one-off fill the user doesn't want remembered).
public enum SessionMode: String, Sendable, Codable, Equatable, CaseIterable {
    case normal
    case ephemeral
}

/// Everything a rule needs to decide, as one immutable value — no rule
/// reaches outside this struct (plus the `now`/`window` parameters passed
/// alongside it) for anything, which is what makes the rules pure functions.
public struct PolicyRequest: Sendable, Codable, Equatable {
    public let operation: VaultOperation
    public let sensitivity: SensitivityTier
    public let authFreshness: AuthFreshness
    public let sessionMode: SessionMode
    /// Whether this operation is gated behind a not-yet-built consent flow
    /// (PRD's future cloud-processing opt-in). Default-deny: an operation
    /// that requires consent is denied unless `consentGranted` is explicitly
    /// true — there is no cloud feature yet, so nothing sets this `true`
    /// today, but the gate exists so a future cloud path can't be wired in
    /// without going through it (CLAUDE.md §8.6/§19).
    public let requiresConsent: Bool
    public let consentGranted: Bool

    public init(
        operation: VaultOperation,
        sensitivity: SensitivityTier,
        authFreshness: AuthFreshness,
        sessionMode: SessionMode,
        requiresConsent: Bool = false,
        consentGranted: Bool = false
    ) {
        self.operation = operation
        self.sensitivity = sensitivity
        self.authFreshness = authFreshness
        self.sessionMode = sessionMode
        self.requiresConsent = requiresConsent
        self.consentGranted = consentGranted
    }
}
