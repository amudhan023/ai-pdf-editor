---
type: index
title: UI Index
description: Presentation-layer packages — PrivacyDashboard's view-model layer implemented, VaultManagerUI still a stub, and the App composition root now a minimal shell viewer app.
tags: [ui, presentation-layer, overview]
---

# UI (Presentation Layer)

Per [../architecture/layered-architecture.md](../architecture/layered-architecture.md), Presentation depends only on the Application layer (view models + coordinator protocols) and never touches Infrastructure directly. `PrivacyDashboard` has its view-model/service layer implemented (no views yet); `VaultManagerUI` is still a 4-line placeholder stub. `App/` (the DI composition root, windows, menus — see `App/CLAUDE.md`) is now a minimal shell viewer app (P0-07) that wires `PDFiumEngine` in-process behind `PDFEngineAPI`.

| Package | Owns | Status |
|---|---|---|
| [vault-manager-ui.md](vault-manager-ui.md) | Vault window: profile management, field editing, sensitivity masking, unlock UX | Scaffolded (stub) |
| [privacy-dashboard.md](privacy-dashboard.md) | Trust surface: stored-data summary, audit timeline, network disclosure | Partial — view-models only |

The document viewer UI now lives inside [DocumentSession](../sessions/document-session.md)'s `UI/` subtree (SwiftUI views + view models colocated with the coordinator) rather than a dedicated Presentation package — see the layering note there. The Autofill Review Panel and Ingestion Review UI are still design intent, expected to follow the same colocated pattern in [AutofillSession](../sessions/autofill-session.md)/[IngestionSession](../sessions/ingestion-session.md).
