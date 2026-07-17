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

**Current reality vs. the diagram:** the idealized diagram cleanly separates Presentation from Application, but at least one existing package's own `CLAUDE.md` blurs this — `DocumentSession`'s stated purpose includes "viewer + annotation + form-fill UI," i.e. some Presentation-layer responsibility inside an Application-layer package. This isn't necessarily wrong (SwiftUI view models are often colocated with their coordinator), but it's a real deviation worth checking against the package's `CLAUDE.md` rather than assuming the ARCHITECTURE.md diagram is literally how the code is split today. Practice has since settled the question: `DocumentSession` colocates its SwiftUI views/view model (`UI/`, `Sidebar/`) with the Application-layer coordinator, and `App/` stays a pure composition root. See [module-map.md](module-map.md) for the current per-package status table.
