---
type: index
title: Sessions Index
description: Application-layer workflow state machines — all currently 4-line placeholder stubs.
tags: [sessions, application-layer, overview]
---

# Sessions (Application Layer)

Feature coordinators that own workflow state, undo/session lifecycle, and are the *only* paths by which AI-produced or user-entered data reaches a document or the vault (product truth 2, [../architecture/five-product-truths.md](../architecture/five-product-truths.md)). **All three packages below are currently 4-line placeholder stubs** — the descriptions here are design intent from `docs/ARCHITECTURE.md` and each package's own `CLAUDE.md`, not implemented behavior.

| Package | Owns | Only path for |
|---|---|---|
| [document-session.md](document-session.md) | Open/edit/atomic-save/backup lifecycle, undo stack | — |
| [autofill-session.md](autofill-session.md) | Fill workflow state machine + review panel | Proposals reaching a document |
| [ingestion-session.md](ingestion-session.md) | Ingestion workflow state machine + review UI | Extracted data reaching the vault |
