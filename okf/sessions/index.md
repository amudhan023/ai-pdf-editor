---
type: index
title: Sessions Index
description: Application-layer workflow state machines — DocumentSession partially implemented (atomic save + viewer); AutofillSession and IngestionSession still stubs.
tags: [sessions, application-layer, overview]
---

# Sessions (Application Layer)

Feature coordinators that own workflow state, undo/session lifecycle, and are the *only* paths by which AI-produced or user-entered data reaches a document or the vault (product truth 2, [../architecture/five-product-truths.md](../architecture/five-product-truths.md)). `DocumentSession` now has a real implementation (atomic save + the tiled viewer); `AutofillSession` and `IngestionSession` are still 4-line placeholder stubs whose descriptions are design intent from `docs/ARCHITECTURE.md` and each package's own `CLAUDE.md`.

| Package | Owns | Only path for | Status |
|---|---|---|---|
| [document-session.md](document-session.md) | Open/edit/atomic-save/backup lifecycle, undo stack | — | Partial — save path + viewer; no undo yet |
| [autofill-session.md](autofill-session.md) | Fill workflow state machine + review panel | Proposals reaching a document | Scaffolded (stub) |
| [ingestion-session.md](ingestion-session.md) | Ingestion workflow state machine + review UI | Extracted data reaching the vault | Scaffolded (stub) |
