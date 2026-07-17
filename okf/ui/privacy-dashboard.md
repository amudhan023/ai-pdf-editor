---
type: ui-component
title: PrivacyDashboard
description: The trust surface — stored-data summary, audit timeline, network activity disclosure and vault actions. View-models implemented; SwiftUI views not yet built.
tags: [ui-component, presentation-layer, privacy, audit]
implementation_status: partial
---

# PrivacyDashboard

**Purpose:** the product's trust surface — a stored-data summary, an audit timeline, and network activity disclosure/toggles (surfacing the two individually-toggleable, logged app-level network paths: update check and license validation — see [../architecture/process-topology.md](../architecture/process-topology.md)).

## Current state (P3-03)

The view-model/service layer is implemented in `Packages/PrivacyDashboard/Sources/PrivacyDashboard/`: `StorageSummary` (per-section presence counts — what's stored, never the values), `ActivityTimeline` (reads `AuditLog` entries for display), `NetworkActivity` (disclosure of the enumerated app-level network paths), `VaultActions` (lock/crypto-shred affordances routed through ticketed `VaultAPI` calls), `VaultFieldCatalog`, and `PrivacyDashboardError`. **No SwiftUI views yet** — this is the headless layer the eventual dashboard window will render.

## Design

Reads from `AuditLog` ([../packages/audit-log.md](../packages/audit-log.md)) to render the append-only, hash-chained, tamper-evident activity timeline (IDs/paths/hashes only, never values, per root CLAUDE.md §16). This is the UI backing product truth 3 ("every value is traceable to its source") made visible to the user, and the concrete demonstration of Constitution Article 1's "no content leaves the device" claim being auditable rather than just promised.

## Allowed imports

Foundation, `AuditLog`, `VaultAPI`.
