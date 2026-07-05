import XCTest
import LocalAuthentication
@testable import Platform

/// Real `LAContext` evaluation needs a Security Server session unavailable
/// in this sandbox (see `LAContextAuthenticator`'s doc comment), so this
/// pins the one piece of pure logic the type owns: `LAError` → typed
/// `LocalAuthenticationError` mapping.
final class LocalAuthenticatorTests: XCTestCase {
    func testMapsUserCancelVariants() {
        for code in [LAError.userCancel, .systemCancel, .appCancel] {
            let error = NSError(domain: LAError.errorDomain, code: code.rawValue)
            XCTAssertEqual(LAContextAuthenticator.map(error), .userCancelled)
        }
    }

    func testMapsPasscodeNotSet() {
        let error = NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        XCTAssertEqual(LAContextAuthenticator.map(error), .passcodeNotSet)
    }

    func testMapsBiometryUnavailableVariants() {
        for code in [LAError.biometryNotAvailable, .biometryNotEnrolled, .biometryLockout] {
            let error = NSError(domain: LAError.errorDomain, code: code.rawValue)
            XCTAssertEqual(LAContextAuthenticator.map(error), .biometryNotAvailable)
        }
    }

    func testMapsUnknownAndNilToFailed() {
        let error = NSError(domain: LAError.errorDomain, code: LAError.authenticationFailed.rawValue)
        XCTAssertEqual(LAContextAuthenticator.map(error), .failed)
        XCTAssertEqual(LAContextAuthenticator.map(nil), .failed)
    }
}
