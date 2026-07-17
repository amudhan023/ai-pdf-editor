---
type: index
title: UI Index
description: Presentation-layer packages — PrivacyDashboard partial, VaultManagerUI stub (P1-11 in progress), App composition root real.
tags: [ui, presentation-layer, overview]
---

# UI (Presentation Layer)

Per [../architecture/layered-architecture.md](../architecture/layered-architecture.md), Presentation depends only on the Application layer (view models + coordinator protocols) and never touches Infrastructure directly. `PrivacyDashboard` is partial (P3-03 data surfaces), `VaultManagerUI` is still a stub (P1-11 in progress), and `App/` is a real SwiftPM executable: `AppDelegate.init` is the composition root (the one place allowed to name `PDFiumEngine`), with a `.app`-bundle assembly script — see `App/CLAUDE.md`. Note the viewer UI itself lives in `Packages/DocumentSession` (`UI/`, `Sidebar/`), not here — see [../sessions/document-session.md](../sessions/document-session.md).

| Package | Owns |
|---|---|
| [vault-manager-ui.md](vault-manager-ui.md) | Vault window: profile management, field editing, sensitivity masking, unlock UX |
| [privacy-dashboard.md](privacy-dashboard.md) | Trust surface: stored-data summary, audit timeline, network disclosure |

Document viewer/editor UI, the Autofill Review Panel, and the Ingestion Review UI are described in `docs/ARCHITECTURE.md`'s Presentation layer but don't yet have a dedicated package of their own distinct from [DocumentSession](../sessions/document-session.md)/[AutofillSession](../sessions/autofill-session.md)/[IngestionSession](../sessions/ingestion-session.md) — see the layering note in [document-session.md](../sessions/document-session.md).
