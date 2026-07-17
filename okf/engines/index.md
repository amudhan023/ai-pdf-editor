---
type: index
title: Engines Index
description: Domain engines and Infrastructure host adapters — VaultStore substantively implemented; DocEngineHost/InferenceHost/AutofillEngine partial; IngestionPipeline still a stub.
tags: [engines, domain-layer, infrastructure-layer, overview]
---

# Engines & Hosts

Domain services (pure Swift, UI-free) and the Infrastructure-tier host adapters that implement the frozen `*API` protocols against real backends.

| Package | Layer | Owns | Implements | Status |
|---|---|---|---|---|
| [autofill-engine.md](autofill-engine.md) | Domain | Field discovery, matching ladder, formatting, fill planning | — | Partial — alias-dictionary matcher rung only |
| [ingestion-pipeline.md](ingestion-pipeline.md) | Domain | Stage graph: normalize → OCR → classify → extract → map → conflict-detect | — | Scaffolded (stub) |
| [doc-engine-host.md](doc-engine-host.md) | Infrastructure | PDFium adapter (only package that may link the PDF engine) | [PDFEngineAPI](../packages/pdf-engine-api.md)'s `DocumentLifecycle` + `PageRenderer` | Partial — lifecycle + tiled render; no edit/forms/save |
| [inference-host.md](inference-host.md) | Infrastructure | Model registry, router, memory governor, Vision/embedding providers | [InferenceAPI](../packages/inference-api.md) | Partial — OCR + embed real; Core ML/FoundationModels placeholders |
| [vault-store.md](vault-store.md) | Infrastructure | SQLCipher store, key hierarchy, lock/auth, crypto-shred | [VaultAPI](../packages/vault-api.md)'s `VaultClient` | Implemented (in-process; `Vault.xpc` split pending) |
