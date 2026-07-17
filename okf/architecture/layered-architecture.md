---
type: architecture
title: Layered Architecture
description: The Presentation → Application → Domain → Infrastructure layering and the import rules that make it structural rather than a convention.
tags: [architecture, layering, boundaries]
implementation_status: partial
---

# Layered Architecture

Four layers, each only depending on the one below it (`docs/ARCHITECTURE.md` §2.2):

- **Presentation** (SwiftUI + AppKit) — Document Windows, Autofill Review Panel, Vault Manager UI, Ingestion Review UI, Privacy Dashboard. Depends only on Application (view models + coordinator protocols).
- **Application** (Feature Coordinators) — `DocumentSession`, `AutofillSession`, `IngestionSession`, a `VaultCoordinator`. Orchestrates Domain services; owns undo/session state; never touches Infrastructure directly.
- **Domain Services** — `PDF Engine Facade` (`PDFEngineAPI`), `AutofillEngine`, `IngestionPipeline`, `Vault Service Client` (`VaultAPI`), `PolicyKit`, `FormKnowledge`. Pure Swift, UI-free, testable headless; speak to Infrastructure only through protocols.
- **Infrastructure** — Render/Parse XPC (`DocEngineHost`), ML Inference XPC (`InferenceHost`), Vault XPC (`VaultStore`), storage (GRDB/SQLCipher, model packs), OS services (`Platform`: Keychain, Secure Enclave, Vision, LocalAuthentication). Only this layer may import GRDB, Core ML, PDF-engine internals, or XPC.

**Enforcement mechanism:** this isn't just a convention — it's enforced by SPM target boundaries and `Scripts/check-boundaries.sh` against `Scripts/import-allowlist.txt`, run as part of `Scripts/verify.sh <Package>` and CI. A package can only import Foundation-tier deps plus its declared `*API` packages; there is no way to create hidden coupling that passes CI. See root CLAUDE.md §3.1 and §17.

**Current reality vs. the diagram:** the idealized diagram cleanly separates Presentation from Application, and the code has now deviated from it deliberately — `DocumentSession` contains the viewer's SwiftUI views and view models in its `UI/` subtree (per its own `CLAUDE.md`'s "viewer + annotation + form-fill UI" scope), with `App/` as a thin composition root that injects the concrete engine ([../sessions/document-session.md](../sessions/document-session.md)). Another accepted deviation: the Keychain and file-coordination wrappers the diagram assigns to `Platform` live today in `VaultStore` and `DocumentSession` respectively, colocated with their sole consumers. The sessions/engines for autofill and ingestion are still stubs or partial — see [module-map.md](module-map.md) for the per-package status.
