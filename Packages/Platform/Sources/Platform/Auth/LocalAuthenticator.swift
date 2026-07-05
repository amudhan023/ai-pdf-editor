import Foundation
import LocalAuthentication

/// Typed outcome of an explicit re-authentication prompt (Touch ID/Apple
/// Watch/password), independent of whatever access-control-gated Secure
/// Enclave operation a caller might *also* be doing. This is for flows that
/// need a fresh auth signal without unwrapping any key — e.g. PolicyKit's
/// `requireReauth` decision bumping a vault's auth-freshness timestamp.
public enum LocalAuthenticationError: Error, Sendable, Equatable {
    case biometryNotAvailable
    case userCancelled
    case passcodeNotSet
    case failed
}

/// Abstraction over `LocalAuthentication.LAContext` so callers (and their
/// tests) never depend on real biometric hardware directly.
public protocol LocalAuthenticating: Sendable {
    func authenticate(reason: String) async throws
}

/// Real implementation: `LAPolicy.deviceOwnerAuthentication` (biometry, with
/// device-passcode fallback per ARCHITECTURE.md §6.2's "Touch ID/Apple
/// Watch/password"). Not exercised end-to-end by this package's test suite —
/// evaluating this policy requires a real Security Server session, the same
/// environment gap `SecureEnclaveKeyBox` documents; error-mapping logic is
/// tested against `LAError` codes directly instead.
public struct LAContextAuthenticator: LocalAuthenticating {
    public init() {}

    public func authenticate(reason: String) async throws {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw Self.map(policyError)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Self.map(evalError as NSError?))
                }
            }
        }
    }

    static func map(_ error: NSError?) -> LocalAuthenticationError {
        guard let error, error.domain == LAError.errorDomain, let code = LAError.Code(rawValue: error.code) else {
            return .failed
        }
        switch code {
        case .userCancel, .systemCancel, .appCancel:
            return .userCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout:
            return .biometryNotAvailable
        default:
            return .failed
        }
    }
}
