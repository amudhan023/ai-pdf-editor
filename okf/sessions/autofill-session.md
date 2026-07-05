---
type: session
title: AutofillSession
description: Autofill workflow state machine and review-before-commit panel — the only path proposals reach a document. Currently a placeholder stub.
tags: [session, application-layer, autofill, review-ui, stub]
implementation_status: scaffolded
---

# AutofillSession

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the autofill workflow state machine and its review-before-commit panel. This is *the only path* by which an `AutofillEngine` proposal can reach a document — the engine itself must never write ([../engines/autofill-engine.md](../engines/autofill-engine.md)).

## Current state

`Packages/AutofillSession/Sources/AutofillSession/AutofillSession.swift` is a 4-line placeholder. No state machine or review model exists yet.

## Design intent (`docs/ARCHITECTURE.md` §5.2 — see [../workflows/autofill-flow.md](../workflows/autofill-flow.md) for the full sequence)

Coordinates: form-model discovery (via `DocEngineHost`), `FormKnowledge` fingerprint lookup, `AutofillEngine` semantic matching, `PolicyKit` read-grant requests, `VaultAPI` field reads, value formatting, presenting the review panel (proposals + confidence + source), committing accepted values back through the doc engine, and an `AuditLog` entry. Also handles the "accept-all-high-confidence" and per-field edit/reject flows named in the PRD.

## Allowed imports

Foundation, `AutofillEngine`, `VaultAPI`, `PolicyKit`, `PDFEngineAPI`.
