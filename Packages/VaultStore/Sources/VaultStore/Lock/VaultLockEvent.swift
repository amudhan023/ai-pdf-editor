import Foundation

/// Why the vault transitioned to `.locked` — surfaced so later UI/audit
/// consumers (P1-11, P1-15) can distinguish "user chose this" from
/// "the system did this for you" without re-deriving it from timestamps.
public enum VaultLockReason: Sendable, Equatable {
    case manual
    case idleTimeout
    case systemSleepOrScreenLock
}

/// Domain events `VaultLockController` emits on every lock-state
/// transition (task requirement: "`VaultDidLock/Unlock` domain events").
/// Consumed via `VaultLockController.events`; this package has no
/// general-purpose event bus yet (that's P1-15's scope if/when it's built),
/// so this is a narrow, single-purpose `AsyncStream` rather than a new
/// cross-cutting abstraction.
public enum VaultLockEvent: Sendable, Equatable {
    case didUnlock(at: Date)
    case didLock(reason: VaultLockReason, at: Date)
}
