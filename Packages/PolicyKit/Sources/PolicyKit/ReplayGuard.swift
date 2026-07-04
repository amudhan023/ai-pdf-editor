import Foundation

/// Tracks consumed ticket IDs to reject replay. This is the one piece of
/// PolicyKit that isn't a pure function — replay detection inherently needs
/// state across calls. It's in-memory only (an `actor`, no disk/network),
/// which is why it doesn't violate the package's "zero I/O" invariant: I/O
/// here means external side effects (filesystem, network, Keychain), not
/// "holds any state at all." Process-lifetime only — a restart clears it,
/// which is acceptable because tickets are short-TTL by design (an expired
/// ticket fails `TicketVerifier` regardless of replay history).
public actor ReplayGuard {
    private var consumedTicketIDs: Set<UUID> = []

    public init() {}

    /// Returns `true` and records the ID the first time it's seen; `false`
    /// (does not re-record) on every subsequent call for the same ID.
    @discardableResult
    public func consume(_ id: UUID) -> Bool {
        guard !consumedTicketIDs.contains(id) else { return false }
        consumedTicketIDs.insert(id)
        return true
    }
}
