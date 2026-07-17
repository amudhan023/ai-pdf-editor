---
type: package
title: AuditLog
description: Append-only, hash-chained local audit log — IDs/paths/hashes only, never values; chain verification, rotation, bounded archival, filtered reads, event subscription.
tags: [package, infrastructure, audit, privacy]
implementation_status: implemented
---

# AuditLog

**Purpose:** an append-only, hash-chained local log of ingestions, fills, vault access, and network events (which should always be none). Backs the Privacy Dashboard ([../ui/privacy-dashboard.md](../ui/privacy-dashboard.md)). Its entry type has no value slot at all — that's a structural privacy guarantee, not just a convention ("keep it that way," per its `CLAUDE.md`).

## Current state (P1-15, P1-18)

Implemented in `Packages/AuditLog/Sources/AuditLog/` (`AuditEntry.swift`, `AuditLog.swift`):

- `AuditEntry` — closed metadata types with no free-form value slot; entries carry IDs, paths, and hashes only.
- `AuditLog` — an `actor` (every append naturally serialized without a `DispatchQueue`), hash-chained for tamper evidence, with chain verification, rotation, bounded archival, filtered reads, and an event-subscription hook. A cached last-hash avoids the O(n²) chain re-walk an earlier version had.

Consumed today by `VaultStore`'s `DomainEventAuditAdapter` (P1-18), which durably appends vault domain events arriving on `Platform`'s `DomainEventBus` ([../engines/vault-store.md](../engines/vault-store.md)), and by `PrivacyDashboard`'s activity-timeline view-models ([../ui/privacy-dashboard.md](../ui/privacy-dashboard.md)).

## Design (`docs/ARCHITECTURE.md` §3.2, §5.3)

Structured, hash-chained (tamper-evident), rendered by the Privacy Dashboard. Logged at the level of IDs, paths, and hashes — never field values or document content (root CLAUDE.md §16's absolute logging rule extends to this store specifically). Future consumers: `AutofillSession`, `IngestionSession` (append an entry after every privileged operation) — both still stubs.

## Allowed imports

Foundation only.
