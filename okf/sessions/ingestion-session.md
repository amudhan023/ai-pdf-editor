---
type: session
title: IngestionSession
description: Ingestion workflow state machine and review UI — the only path extracted data reaches the vault. Currently a placeholder stub.
tags: [session, application-layer, ingestion, review-ui, stub]
implementation_status: scaffolded
---

# IngestionSession

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the ingestion workflow state machine and its review UI. This is *the only path* by which data extracted from an ingested document reaches the vault — `IngestionPipeline` itself must never write to the vault directly ([../engines/ingestion-pipeline.md](../engines/ingestion-pipeline.md)).

## Current state

`Packages/IngestionSession/Sources/IngestionSession/IngestionSession.swift` is a 4-line placeholder. No state machine or review model exists yet.

## Design intent (`docs/ARCHITECTURE.md` §5.1 — see [../workflows/ingestion-flow.md](../workflows/ingestion-flow.md) for the full sequence)

Coordinates: handing a document to `IngestionPipeline`, presenting extracted candidates with source snippets for accept/edit/reject, requesting a `PolicyKit` write grant for the accepted set, committing via `VaultAPI`, and appending an `AuditLog` entry. Also owns "ephemeral mode" — skipping the vault-write path entirely so candidates live only in session memory, never persisted (see [../architecture/security-model.md](../architecture/security-model.md)'s ephemeral-write-always-denies rule in `PolicyRules`).

## Allowed imports

Foundation, `IngestionPipeline`, `VaultAPI`, `PolicyKit`.
