---
type: package
title: AuditLog
description: Append-only, hash-chained local audit log — IDs/paths/hashes only, never values. Currently a placeholder stub.
tags: [package, infrastructure, audit, privacy, stub]
implementation_status: scaffolded
---

# AuditLog

**Purpose (per its `CLAUDE.md`, not yet realized in code):** an append-only, hash-chained local log of ingestions, fills, vault access, and network events (which should always be none). Backs the Privacy Dashboard ([../ui/privacy-dashboard.md](../ui/privacy-dashboard.md)). Its entry type must have no value slot at all — that's a structural privacy guarantee, not just a convention ("keep it that way," per its `CLAUDE.md`).

## Current state

`Packages/AuditLog/Sources/AuditLog/AuditLog.swift` is a 4-line placeholder. No entry type, hash-chaining, or persistence exists yet.

## Design intent (`docs/ARCHITECTURE.md` §3.2, §5.3)

Structured, hash-chained (tamper-evident), rendered by the Privacy Dashboard. Logged at the level of IDs, paths, and hashes — never field values or document content (root CLAUDE.md §16's absolute logging rule extends to this store specifically). Consumers: `AutofillSession`, `IngestionSession` (append an entry after every privileged operation), `PrivacyDashboard` (reads it for display).

## Allowed imports

Foundation only.

Consumed by (once built): `AutofillSession`, `IngestionSession`, `PrivacyDashboard` — all currently stubs themselves.
