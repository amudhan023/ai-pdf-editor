import XCTest
import VaultAPI
@testable import PolicyKit

/// One test per row of the decision table documented in
/// `PolicyRules.swift` / `docs/specs/policy-decision-table.md`.
final class PolicyRulesDecisionTableTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let window: TimeInterval = 300

    private func request(
        operation: VaultOperation = .read,
        sensitivity: SensitivityTier = .standard,
        secondsSinceAuth: TimeInterval = 0,
        sessionMode: SessionMode = .normal,
        requiresConsent: Bool = false,
        consentGranted: Bool = false
    ) -> PolicyRequest {
        PolicyRequest(
            operation: operation,
            sensitivity: sensitivity,
            authFreshness: AuthFreshness(lastAuthenticatedAt: now.addingTimeInterval(-secondsSinceAuth)),
            sessionMode: sessionMode,
            requiresConsent: requiresConsent,
            consentGranted: consentGranted
        )
    }

    func testRow1_EphemeralWriteAlwaysDenied() {
        let req = request(operation: .write, sensitivity: .standard, sessionMode: .ephemeral)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .deny)
    }

    func testRow1_EphemeralWriteDeniedEvenWithFreshAuthAndStandardSensitivity() {
        let req = request(operation: .write, sensitivity: .standard, secondsSinceAuth: 0, sessionMode: .ephemeral)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .deny)
    }

    func testRow1_EphemeralReadIsNotDeniedByThisRule() {
        // Ephemeral only denies *write* (persistence); reads pass through to later rules.
        let req = request(operation: .read, sensitivity: .standard, sessionMode: .ephemeral)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }

    func testRow2_ConsentRequiredButNotGranted_Denied() {
        let req = request(requiresConsent: true, consentGranted: false)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .deny)
    }

    func testRow2_ConsentRequiredAndGranted_NotDeniedByThisRule() {
        let req = request(requiresConsent: true, consentGranted: true)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }

    func testRow2_ConsentGateOverridesSensitivity_DeniedNotReauth() {
        // Missing consent denies outright - it does not degrade to requireReauth
        // even for sensitive data. There's no "reauth your way past missing consent."
        let req = request(sensitivity: .sensitive, secondsSinceAuth: 10_000, requiresConsent: true, consentGranted: false)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .deny)
    }

    func testRow3_SensitiveWithStaleAuth_RequiresReauth_NeverGrant() {
        let req = request(sensitivity: .sensitive, secondsSinceAuth: window + 1)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .requireReauth)
    }

    func testRow3_SensitiveWithFreshAuth_Granted() {
        let req = request(sensitivity: .sensitive, secondsSinceAuth: 1)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }

    func testRow3_BoundaryExactlyAtWindow_IsFresh() {
        // isFresh uses <=, so exactly-at-window counts as fresh.
        let req = request(sensitivity: .sensitive, secondsSinceAuth: window)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }

    func testRow4_StandardSensitivityStaleAuth_StillGranted() {
        // Staleness only matters for sensitive-tier data.
        let req = request(sensitivity: .standard, secondsSinceAuth: 10_000)
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }

    func testRow4_DefaultGrant() {
        let req = request()
        XCTAssertEqual(PolicyRules.decide(req, now: now, authFreshnessWindow: window), .grant)
    }
}
