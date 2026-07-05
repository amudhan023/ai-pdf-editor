---
type: index
title: UI Index
description: Presentation-layer packages — currently 4-line placeholder stubs, and the App composition root, which doesn't exist as code yet.
tags: [ui, presentation-layer, overview]
---

# UI (Presentation Layer)

Per [../architecture/layered-architecture.md](../architecture/layered-architecture.md), Presentation depends only on the Application layer (view models + coordinator protocols) and never touches Infrastructure directly. **Both packages below are currently 4-line placeholder stubs**, and `App/` (the DI composition root, windows, menus — see `App/CLAUDE.md`) has no Swift files at all yet.

| Package | Owns |
|---|---|
| [vault-manager-ui.md](vault-manager-ui.md) | Vault window: profile management, field editing, sensitivity masking, unlock UX |
| [privacy-dashboard.md](privacy-dashboard.md) | Trust surface: stored-data summary, audit timeline, network disclosure |

Document viewer/editor UI, the Autofill Review Panel, and the Ingestion Review UI are described in `docs/ARCHITECTURE.md`'s Presentation layer but don't yet have a dedicated package of their own distinct from [DocumentSession](../sessions/document-session.md)/[AutofillSession](../sessions/autofill-session.md)/[IngestionSession](../sessions/ingestion-session.md) — see the layering note in [document-session.md](../sessions/document-session.md).
