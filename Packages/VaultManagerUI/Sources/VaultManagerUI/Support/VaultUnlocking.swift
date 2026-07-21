import Foundation
import VaultAPI

/// Performs the actual unlock/lock ceremony (Touch ID/password prompt in
/// production). Abstracted for the same reason as `TicketIssuing`: real
/// unlock is Vault.xpc/Platform's job (`VaultClient` deliberately has no
/// unlock method — see its doc comment), out of this package's reach.
public protocol VaultUnlocking: Sendable {
    /// Prompts for auth and, on success, unlocks and refreshes auth
    /// freshness. Also used for a re-auth prompt while already unlocked
    /// (same LAContext flow in production) — there is no separate
    /// `reauthenticate()`, calling `unlock()` again is the re-auth.
    func unlock() async throws
    func lock() async
}

/// One-time reveal of a wrapped recovery code (P1-09's "Not done" list
/// explicitly hands this UI to whoever picks up P1-11). Recovery-code
/// generation/storage lives in `VaultStore`, unreachable from this package
/// — the composition root supplies the real provider; `FakeRecoveryCodeProvider`
/// stands in for tests/dev.
public protocol RecoveryCodeProviding: Sendable {
    /// Throws on a second call — the ceremony is show-once, enforced by the
    /// provider itself, not just by UI state (a UI bug re-invoking this
    /// must not re-disclose the code).
    func revealOnce() async throws -> String
}

public enum RecoveryCodeError: Error, Sendable, Equatable {
    case alreadyRevealed
}

public actor FakeVaultUnlocker: VaultUnlocking {
    private let client: FakeVaultClient
    private let authFreshnessClock: AuthFreshnessClock

    public init(client: FakeVaultClient, authFreshnessClock: AuthFreshnessClock) {
        self.client = client
        self.authFreshnessClock = authFreshnessClock
    }

    public func unlock() async throws {
        await client.setLockState(.unlocked)
        await authFreshnessClock.noteAuthenticated(at: Date())
    }

    public func lock() async {
        await client.setLockState(.locked)
    }
}

public actor FakeRecoveryCodeProvider: RecoveryCodeProviding {
    private let code: String
    private var revealed = false

    public init(code: String = "FAKE-0000-0000-0000") {
        self.code = code
    }

    public func revealOnce() async throws -> String {
        guard !revealed else { throw RecoveryCodeError.alreadyRevealed }
        revealed = true
        return code
    }
}
