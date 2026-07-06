import Foundation
import VaultAPI
@testable import VaultManagerUI

/// Test-local mocks (CLAUDE.md §5: `Mock*`, not shipped in the package —
/// unlike `VaultAPI.FakeVaultClient`, which is shipped because other
/// packages consume it too).
actor MockTicketProvider: VaultTicketProviding {
    private let signingKey = SymmetricTestKey()
    private var shouldRequireReauth = false
    private var shouldDeny = false
    private(set) var requestedOperations: [VaultOperation] = []

    func setShouldRequireReauth(_ value: Bool) {
        shouldRequireReauth = value
    }

    func setShouldDeny(_ value: Bool) {
        shouldDeny = value
    }

    func requestTicket(
        operation: VaultOperation,
        personID: PersonID,
        scopedPaths: [FieldPath],
        sensitivity: SensitivityTier
    ) async throws -> PolicyTicket {
        requestedOperations.append(operation)
        if shouldDeny { throw VaultTicketRequestError.denied }
        if shouldRequireReauth, sensitivity == .sensitive { throw VaultTicketRequestError.reauthRequired }
        let now = Date()
        return PolicyTicket(
            operation: operation, personID: personID, scopedPaths: scopedPaths,
            issuedAt: now, expiresAt: now.addingTimeInterval(300), signature: Data()
        )
    }
}

/// Placeholder so `MockTicketProvider` doesn't need a real `CryptoKit`
/// import (not on this package's Test-target allowlist beyond what
/// `VaultAPI`/`PolicyKit` already bring in) — `FakeVaultClient` trusts
/// `ticket.signature` unconditionally, so no real signing is needed here.
private struct SymmetricTestKey {}

final class MockUnlocking: VaultUnlocking, @unchecked Sendable {
    var biometricsResult: Result<Void, VaultUnlockError> = .success(())
    var recoveryCodeResult: Result<Void, VaultUnlockError> = .success(())
    private(set) var lockCallCount = 0

    func unlockWithBiometrics() async throws {
        try biometricsResult.get()
    }

    func unlockWithRecoveryCode(_ code: String) async throws {
        try recoveryCodeResult.get()
    }

    func lock() async {
        lockCallCount += 1
    }
}

final class MockRevealAuditing: VaultRevealAuditing, @unchecked Sendable {
    private(set) var reveals: [(path: FieldPath, personID: PersonID)] = []

    func recordReveal(path: FieldPath, personID: PersonID) {
        reveals.append((path, personID))
    }
}
