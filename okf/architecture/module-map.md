---
type: architecture
title: Module Map
description: The SPM package layout, what each package owns and must never do, and its actual implementation status today.
tags: [architecture, packages, spm, ownership]
implementation_status: partial
---

# Module Map

One SPM package per architecture module (`docs/REPO_STRUCTURE.md` §1) — a task assigns an agent one package; the package's `Sources/`, `Tests/`, and `CLAUDE.md` are its whole world. Cross-package coupling only happens through `*API` protocol packages.

| Package | Owns | Must never | Status |
|---|---|---|---|
| `PDFEngineAPI` | Engine-neutral protocols: `PageRenderer`, `TextEditor`, `PageOrganizer`, `AnnotationStore`, `FormModel` | Leak engine-specific types upward | **Implemented** — see [packages/pdf-engine-api.md](../packages/pdf-engine-api.md) |
| `VaultAPI` | Profile schema, field types, sensitivity tiers, `PolicyTicket` shape, `VaultClient` protocol | Contain storage or crypto code | **Implemented** — see [packages/vault-api.md](../packages/vault-api.md) |
| `InferenceAPI` | Typed inference request/response protocols | Contain a real model implementation | **Implemented** (frozen seam) — see [packages/inference-api.md](../packages/inference-api.md) |
| `PolicyKit` | Deterministic rules, ticket minting/verification | Be bypassed; perform I/O in its rule functions | **Implemented** — see [packages/policy-kit.md](../packages/policy-kit.md) |
| `Platform` | Keychain, LAContext, file coordination, XPC transport, domain event bus | — | **Partial** — `XPC/` transport, `Events/` domain event bus (P1-18), `Auth/LocalAuthenticator`; Keychain/file-coordination wrappers not yet — see [packages/platform.md](../packages/platform.md) |
| `DocumentSession` | Document lifecycle, atomic save, viewer + sidebar UI; undo/redo pending | Perform PDF byte manipulation itself | **Partial** — open/save/tiled-viewer/sidebar real (P0-07, P1-16, P1-01, P1-02); undo/dirty/recovery pending — see [sessions/document-session.md](../sessions/document-session.md) |
| `AutofillSession` | Fill workflow state machine + review model | — | **Scaffolded (stub)** — see [sessions/autofill-session.md](../sessions/autofill-session.md) |
| `IngestionSession` | Ingestion workflow state machine + review model | — | **Scaffolded (stub)** — see [sessions/ingestion-session.md](../sessions/ingestion-session.md) |
| `AutofillEngine` | Field discovery, semantic matching, value formatting, fill plan construction | Write into the document | **Partial** — alias dictionary/matcher + label normalizer (P1-14); discovery/formatting/planning pending — see [engines/autofill-engine.md](../engines/autofill-engine.md) |
| `IngestionPipeline` | Stage graph: normalize → OCR → classify → extract → map → conflict-detect | Persist anything without user-confirmed review | **Scaffolded (stub)** — see [engines/ingestion-pipeline.md](../engines/ingestion-pipeline.md) |
| `FormKnowledge` | Form fingerprinting, mapping memory, template packs | Store values | **Scaffolded (stub)** — see [packages/form-knowledge.md](../packages/form-knowledge.md) |
| `AuditLog` | Append-only, hash-chained local log | Log field values | **Implemented** (P1-15/P1-18) — see [packages/audit-log.md](../packages/audit-log.md) |
| `DocEngineHost` | XPC client + PDFium adapter implementing `PDFEngineAPI` | Touch network/vault/unhanded files | **Partial** — lifecycle/tiled-render/outline real against vendored PDFium (P0-06, P1-02); text-edit/annotations/page-ops/forms/save pending — see [engines/doc-engine-host.md](../engines/doc-engine-host.md) |
| `InferenceHost` | Model registry, typed inference endpoints implementing `InferenceAPI` | Load unchecksummed models; make network calls | **Partial** — registry/router/memory-governor + real Vision OCR + embeddings (P1-12/P1-13/P1-14); Core ML/FoundationModels adapters are placeholders — see [engines/inference-host.md](../engines/inference-host.md) |
| `VaultStore` | SQLCipher DB, key hierarchy, lock state, crypto-shred | Return bulk plaintext dumps | **Implemented** (P1-08/09/10; in-process — the `Vault.xpc` split is pending) — see [engines/vault-store.md](../engines/vault-store.md) |
| `VaultManagerUI` | Vault window: profile management, field editing, unlock UX | — | **Scaffolded (stub)**; P1-11 in progress — see [ui/vault-manager-ui.md](../ui/vault-manager-ui.md) |
| `PrivacyDashboard` | Trust surface: stored-data summary, audit timeline, network disclosure | — | **Partial** — view models/data surfaces (P3-03); window UI pending — see [ui/privacy-dashboard.md](../ui/privacy-dashboard.md) |
| `App` | App target: DI composition root, windows/menus | Contain business logic | **Partial** — real SwiftPM executable + composition root, `.app` bundle script (P0-07); tabs/menus polish is P1-07 |

"Scaffolded (stub)" means the package's entire `Sources/` is a single ~4-line placeholder file — the package compiles and has a `CLAUDE.md` describing intended purpose, but no real logic. "Partial" means real, tested logic exists for a subset of the package's charter; the row says which subset. Verify yourself with `find Packages/<Name>/Sources -name '*.swift' | xargs wc -l` if this drifts — and prefer each package's own `CLAUDE.md` (updated in-PR by policy) over this table.
