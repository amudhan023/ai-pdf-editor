---
type: index
title: Engines Index
description: Domain engines and Infrastructure host adapters — all currently 4-line placeholder stubs.
tags: [engines, domain-layer, infrastructure-layer, overview]
---

# Engines & Hosts

Domain services (pure Swift, UI-free) and the Infrastructure-tier host adapters that implement the frozen `*API` protocols against real backends. **All five packages below are currently 4-line placeholder stubs** — descriptions are design intent from `docs/ARCHITECTURE.md` and each package's own `CLAUDE.md`.

| Package | Layer | Owns | Implements |
|---|---|---|---|
| [autofill-engine.md](autofill-engine.md) | Domain | Field discovery, matching ladder, formatting, fill planning | — |
| [ingestion-pipeline.md](ingestion-pipeline.md) | Domain | Stage graph: normalize → OCR → classify → extract → map → conflict-detect | — |
| [doc-engine-host.md](doc-engine-host.md) | Infrastructure | XPC client + PDFium adapter | [PDFEngineAPI](../packages/pdf-engine-api.md) |
| [inference-host.md](inference-host.md) | Infrastructure | XPC client + model registry/adapters | [InferenceAPI](../packages/inference-api.md) |
| [vault-store.md](vault-store.md) | Infrastructure | SQLCipher store, key hierarchy, lock state | [VaultAPI](../packages/vault-api.md)'s `VaultClient` |
