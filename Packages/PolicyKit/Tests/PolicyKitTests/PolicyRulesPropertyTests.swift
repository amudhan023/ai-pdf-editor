import XCTest
import VaultAPI
@testable import PolicyKit

/// Property-based: across many random `(operation, tier, freshness,
/// mode, consent)` combinations, the rules must never produce an unsafe
/// `.grant` — specifically, never grant a sensitive-tier operation with
/// stale auth, never grant an ephemeral write, never grant a
/// consent-required-but-not-granted operation. Seeded (deterministic) so a
/// failure is always reproducible, per this task's acceptance criteria.
final class PolicyRulesPropertyTests: XCTestCase {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    func testNeverGrantsSensitiveOperationWithStaleAuth() {
        var rng = SeededGenerator(state: 0xC0FFEE)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let window: TimeInterval = 300

        for _ in 0..<2000 {
            let operation = VaultOperation.allCases.randomElement(using: &rng)!
            let sensitivity = SensitivityTier.allCases.randomElement(using: &rng)!
            let sessionMode = SessionMode.allCases.randomElement(using: &rng)!
            let requiresConsent = Bool.random(using: &rng)
            let consentGranted = Bool.random(using: &rng)
            // Bias toward the boundary: seconds-since-auth from 0 to 2x the window.
            let secondsSinceAuth = TimeInterval(Int.random(in: 0...Int(window * 2), using: &rng))

            let request = PolicyRequest(
                operation: operation,
                sensitivity: sensitivity,
                authFreshness: AuthFreshness(lastAuthenticatedAt: now.addingTimeInterval(-secondsSinceAuth)),
                sessionMode: sessionMode,
                requiresConsent: requiresConsent,
                consentGranted: consentGranted
            )
            let decision = PolicyRules.decide(request, now: now, authFreshnessWindow: window)

            let authIsStale = secondsSinceAuth > window
            if sensitivity == .sensitive, authIsStale {
                XCTAssertNotEqual(
                    decision, .grant,
                    "unsafe grant: sensitive tier with stale auth (secondsSinceAuth=\(secondsSinceAuth)) must never grant"
                )
            }
            if sessionMode == .ephemeral, operation == .write {
                XCTAssertEqual(decision, .deny, "ephemeral write must always deny, got \(decision)")
            }
            if requiresConsent, !consentGranted {
                XCTAssertEqual(decision, .deny, "consent-required-but-not-granted must always deny, got \(decision)")
            }
        }
    }
}
