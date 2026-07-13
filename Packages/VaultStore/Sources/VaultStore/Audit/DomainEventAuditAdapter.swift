import Foundation
import Platform
import AuditLog
import VaultAPI

/// `Platform.DomainEvent` only has `vaultRead`/`vaultWrite` cases, not the
/// full `VaultAPI.VaultOperation` set — `compareRead` never reveals a
/// value (ARCHITECTURE.md §5.1) so it audits as a read, and `cryptoShred`
/// is a destructive write so it audits as a write; both still carry their
/// real field path/ticket for the audit trail.
extension VaultOperation {
    func asDomainEvent(fieldPath: String?, ticketID: String?) -> DomainEvent {
        switch self {
        case .read, .compareRead:
            return .vaultRead(fieldPath: fieldPath, ticketID: ticketID)
        case .write, .cryptoShred:
            return .vaultWrite(fieldPath: fieldPath, ticketID: ticketID)
        }
    }
}

/// Conforms `Platform.DomainEvent` to `AuditLog.AuditableEvent` (P1-18).
/// This is the adapter both leaf packages' doc comments point to: neither
/// `Platform` nor `AuditLog` depends on the other, so the mapping lives
/// here, in the first package with a legitimate reason to depend on both
/// (`VaultLockController`/`SQLCipherVaultStore` are the first real emitters
/// of privileged-operation `DomainEvent`s). `@retroactive` because this
/// package owns neither the type nor the protocol.
extension DomainEvent: @retroactive AuditableEvent {
    public var auditEventType: AuditEventType {
        switch self {
        case .vaultRead: return .vaultRead
        case .vaultWrite: return .vaultWrite
        case .ingestionCommitted: return .ingestionCommitted
        case .fillCommitted: return .fillCommitted
        case .networkEvent: return .networkEvent
        case .authEvent: return .authEvent
        }
    }

    public var auditFieldPath: String? {
        switch self {
        case .vaultRead(let fieldPath, _), .vaultWrite(let fieldPath, _), .fillCommitted(let fieldPath, _):
            return fieldPath
        case .ingestionCommitted, .networkEvent, .authEvent:
            return nil
        }
    }

    public var auditTicketID: String? {
        switch self {
        case .vaultRead(_, let ticketID), .vaultWrite(_, let ticketID), .fillCommitted(_, let ticketID),
             .ingestionCommitted(let ticketID), .networkEvent(let ticketID), .authEvent(let ticketID):
            return ticketID
        }
    }

    public var auditMetadata: [AuditMetadataEntry]? { nil }
}

/// Subscribes to a `Platform.DomainEventBus` and durably appends every
/// published event to an `AuditLog.AuditLogStore` before `handle` returns —
/// since `DomainEventBus.publish` awaits every subscriber, a caller that
/// awaits `publish` only sees the privileged operation as committed once
/// this append is on disk (task requirement: "audit entry verifiably
/// durable before the operation is reported as committed").
public struct AuditLogDomainEventSubscriber: DomainEventSubscriber {
    private let auditLogStore: AuditLogStore

    public init(auditLogStore: AuditLogStore) {
        self.auditLogStore = auditLogStore
    }

    public func handle(_ event: DomainEvent) async throws {
        try await auditLogStore.append(
            eventType: event.auditEventType,
            fieldPath: event.auditFieldPath,
            ticketID: event.auditTicketID,
            metadata: event.auditMetadata
        )
    }
}
