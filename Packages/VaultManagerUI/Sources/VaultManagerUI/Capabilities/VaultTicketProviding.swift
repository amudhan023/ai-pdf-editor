import Foundation
import VaultAPI

/// Outcome of a ticket request that wasn't a hard failure — distinct from
/// `VaultError`/`Error` cases below because both are legitimate UX states,
/// not exceptions (CLAUDE.md §15's "uncertainty is a low-confidence result,
/// not an error" spirit extended to policy outcomes).
public enum VaultTicketRequestError: Error, Sendable, Equatable {
    /// The requested operation needs a fresher auth signal (PolicyKit's
    /// `.requireReauth`) — callers show a reauth prompt and retry, they
    /// don't treat this as a failure to surface as an error banner.
    case reauthRequired
    case denied
}

/// Capability seam for obtaining a signed `PolicyTicket`. `VaultManagerUI`
/// never holds vault key material itself (Constitution: the master key
/// lives only in `Vault.xpc`, `mlock`ed) — minting is delegated to whatever
/// the composition root wires in (eventually a `Vault.xpc` client), so this
/// package only depends on the capability's shape, not its implementation.
/// Tests use a `Mock*` (test-local, not shipped) against this protocol.
public protocol VaultTicketProviding: Sendable {
    func requestTicket(
        operation: VaultOperation,
        personID: PersonID,
        scopedPaths: [FieldPath],
        sensitivity: SensitivityTier
    ) async throws -> PolicyTicket
}
