import Foundation

/// The outcome of a policy decision. `requireReauth` is deliberately distinct
/// from `deny` — the operation isn't forbidden, it just needs a fresher auth
/// signal before it can be granted (CLAUDE.md's "vault-locked is a normal
/// state, not an error" philosophy extends to this: stale-auth is a UX
/// affordance, not a failure).
public enum PolicyDecision: String, Sendable, Codable, Equatable, CaseIterable {
    case grant
    case deny
    case requireReauth
}
