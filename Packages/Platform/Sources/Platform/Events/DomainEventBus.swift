import Foundation

/// Domain events any privileged operation may announce. Carries the same
/// non-value shape the audit log requires (CLAUDE.md §8.3) — IDs and paths,
/// never field values or document content — so any subscriber, including a
/// future audit consumer, can be handed these directly.
public enum DomainEvent: Sendable, Equatable {
    case vaultRead(fieldPath: String?, ticketID: String?)
    case vaultWrite(fieldPath: String?, ticketID: String?)
    case ingestionCommitted(ticketID: String?)
    case fillCommitted(fieldPath: String?, ticketID: String?)
    case networkEvent(ticketID: String?)
    case authEvent(ticketID: String?)
}

public protocol DomainEventSubscriber: Sendable {
    func handle(_ event: DomainEvent) async throws
}

/// Actor-serialized fan-out bus for domain events (Platform's purpose
/// already names this as infra it owns). `publish` awaits every subscriber
/// before returning — that is what gives a privileged caller (e.g. a fill
/// commit) the "committed only once its audit entry is durable" guarantee:
/// whichever subscriber performs the durable write is on the critical path
/// of `publish`, not a fire-and-forget notification.
///
/// Deliberately has no dependency on `AuditLog` (or vice versa): per
/// CLAUDE.md §3.7 a new cross-package dependency needs its own ADR. The
/// adapter that conforms a concrete subscriber to both `DomainEvent` and
/// AuditLog's `AuditableEvent` belongs in whichever package first needs
/// both wired together (a session/composition root), not in either leaf
/// package.
public actor DomainEventBus {
    private var subscribers: [DomainEventSubscriber] = []

    public init() {}

    public func subscribe(_ subscriber: DomainEventSubscriber) {
        subscribers.append(subscriber)
    }

    public func publish(_ event: DomainEvent) async throws {
        for subscriber in subscribers {
            try await subscriber.handle(event)
        }
    }
}
