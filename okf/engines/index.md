---
type: index
title: Engines Index
description: Domain engines and Infrastructure host adapters — status varies per package; see each file's implementation_status.
tags: [engines, domain-layer, infrastructure-layer, overview]
---

# Engines & Hosts

Domain services (pure Swift, UI-free) and the Infrastructure-tier host adapters that implement the frozen `*API` protocols against real backends. Status varies per package now — each concept file's `implementation_status` frontmatter is the quick answer; [../architecture/module-map.md](../architecture/module-map.md) has the full table.

| Package | Layer | Owns | Implements |
|---|---|---|---|
| [autofill-engine.md](autofill-engine.md) | Domain | Field discovery, matching ladder, formatting, fill planning | — |
| [ingestion-pipeline.md](ingestion-pipeline.md) | Domain | Stage graph: normalize → OCR → classify → extract → map → conflict-detect | — |
| [doc-engine-host.md](doc-engine-host.md) | Infrastructure | XPC client + PDFium adapter | [PDFEngineAPI](../packages/pdf-engine-api.md) |
| [inference-host.md](inference-host.md) | Infrastructure | XPC client + model registry/adapters | [InferenceAPI](../packages/inference-api.md) |
| [vault-store.md](vault-store.md) | Infrastructure | SQLCipher store, key hierarchy, lock state | [VaultAPI](../packages/vault-api.md)'s `VaultClient` |
