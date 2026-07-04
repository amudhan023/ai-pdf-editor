import Foundation
import VaultAPI

/// Deterministic, pure-function policy rules. No I/O, no randomness, no
/// hidden state — every decision is a total function of `(request, now,
/// authFreshnessWindow)`. This is the one thing PolicyKit is not allowed to
/// compromise on (ARCHITECTURE.md driver 4, root CLAUDE.md §2 "deterministic
/// first"); if a future rule seems to need I/O, that's a design smell to
/// escalate, not code to write here.
///
/// **Decision table** (evaluated in this order — first matching row wins;
/// full table also published in docs/specs/policy-decision-table.md):
///
/// | # | sessionMode | operation | requiresConsent | consentGranted | sensitivity | authFresh | Decision |
/// |---|---|---|---|---|---|---|---|
/// | 1 | ephemeral | write | any | any | any | any | `deny` |
/// | 2 | any | any | true | false | any | any | `deny` |
/// | 3 | any | any | any | any | sensitive | false | `requireReauth` |
/// | 4 | (else) | | | | | | `grant` |
///
/// Row 1 (ephemeral-denies-persist) and row 2 (consent default-deny) are
/// checked before row 3 (sensitivity/reauth) deliberately: an ephemeral
/// write is denied outright even with fresh auth (nothing should persist in
/// that mode, reauth wouldn't change that), and an ungranted consent gate
/// denies regardless of how sensitive the data is (there's no "reauth your
/// way past missing consent").
public enum PolicyRules {
    /// Default window for "auth is still fresh." Callers may override per
    /// call site (e.g. a stricter window for crypto-shred); this default is
    /// what "Sensitive-tier read with stale auth" in the task's acceptance
    /// criteria is evaluated against when no window is specified.
    public static let defaultAuthFreshnessWindow: TimeInterval = 5 * 60

    public static func decide(
        _ request: PolicyRequest,
        now: Date = Date(),
        authFreshnessWindow: TimeInterval = defaultAuthFreshnessWindow
    ) -> PolicyDecision {
        if request.sessionMode == .ephemeral, request.operation == .write {
            return .deny
        }
        if request.requiresConsent, !request.consentGranted {
            return .deny
        }
        if request.sensitivity == .sensitive, !request.authFreshness.isFresh(at: now, within: authFreshnessWindow) {
            return .requireReauth
        }
        return .grant
    }
}
