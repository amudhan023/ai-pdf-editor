---
type: ui-component
title: PrivacyDashboard
description: The trust surface — stored-data summary, audit timeline, network activity disclosure and toggles. Currently a placeholder stub.
tags: [ui-component, presentation-layer, privacy, audit, stub]
implementation_status: partial
---

# PrivacyDashboard

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the product's trust surface — a stored-data summary, an audit timeline, and network activity disclosure/toggles (surfacing the two individually-toggleable, logged app-level network paths: update check and license validation — see [../architecture/process-topology.md](../architecture/process-topology.md)).

## Current state

Partial (P3-03): data surfaces exist — `StorageSummary`, `ActivityTimeline` (over AuditLog), `NetworkActivity` disclosure, `VaultActions`, `VaultFieldCatalog`, typed errors. Window/views integration into the app shell is still pending.

## Design intent

Reads from `AuditLog` ([../packages/audit-log.md](../packages/audit-log.md)) — itself a stub — to render the append-only, hash-chained, tamper-evident activity timeline (IDs/paths/hashes only, never values, per root CLAUDE.md §16). This is the UI backing product truth 3 ("every value is traceable to its source") made visible to the user, and the concrete demonstration of Constitution Article 1's "no content leaves the device" claim being auditable rather than just promised.

## Allowed imports

Foundation, `AuditLog`, `VaultAPI`.
