---
type: index
title: Sessions Index
description: Application-layer workflow coordinators — DocumentSession substantially real; Autofill/Ingestion sessions still stubs.
tags: [sessions, application-layer, overview]
---

# Sessions (Application Layer)

Feature coordinators that own workflow state, undo/session lifecycle, and are the *only* paths by which AI-produced or user-entered data reaches a document or the vault (product truth 2, [../architecture/five-product-truths.md](../architecture/five-product-truths.md)). `DocumentSession` is substantially implemented (open/atomic-save/tiled viewer/sidebar — see [document-session.md](document-session.md)); `AutofillSession` and `IngestionSession` are still 4-line stubs whose descriptions are design intent.

| Package | Owns | Only path for |
|---|---|---|
| [document-session.md](document-session.md) | Open/edit/atomic-save/backup lifecycle, undo stack | — |
| [autofill-session.md](autofill-session.md) | Fill workflow state machine + review panel | Proposals reaching a document |
| [ingestion-session.md](ingestion-session.md) | Ingestion workflow state machine + review UI | Extracted data reaching the vault |
