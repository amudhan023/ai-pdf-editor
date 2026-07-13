import Foundation
import AuditLog

/// Read-side view-model over `AuditLogStore` for the dashboard's Activity
/// view: a filterable timeline plus a chain-verification status indicator
/// (PRD FR-5.2). Entries are `AuditLog.AuditEntry` as-is — they already
/// carry only IDs/paths/hashes, never values (`AuditLog`'s own invariant),
/// so there is nothing to redact on the way through.
public struct ActivityTimelineViewModel: Sendable {
    private let store: AuditLogStore

    public init(store: AuditLogStore) {
        self.store = store
    }

    /// The filtered timeline, newest first — `AuditLogStore.entries` reads
    /// segments oldest-first (append order), so this reverses for display.
    public func timeline(matching filter: AuditEntryFilter = AuditEntryFilter()) async throws -> [AuditEntry] {
        try await store.entries(matching: filter).reversed()
    }

    /// Whether the hash chain across every segment (archived + live) still
    /// verifies — surfaced as a status indicator, not silently swallowed
    /// (CLAUDE.md §7.9: a security defect found here is Sev-1, not a footnote).
    public func isChainIntact() async -> Bool {
        await store.verifyChain()
    }
}
