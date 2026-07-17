---
type: engine
title: InferenceHost
description: Model registry, router, memory governor, and Vision/embedding providers implementing InferenceAPI — Core ML and FoundationModels adapters are placeholders.
tags: [engine, infrastructure-layer, ml, xpc-client]
implementation_status: partial
---

# InferenceHost

**Purpose:** the XPC client plus model registry/adapters (Vision, Core ML, FoundationModels) implementing `InferenceAPI` ([../packages/inference-api.md](../packages/inference-api.md)). Models load only after signature + checksum verification; an unverified model path must be refused, not warned about.

## Current state (P1-12, P1-13, P1-14)

Implemented in `Packages/InferenceHost/Sources/InferenceHost/`:

- **`InferenceHostClient`** — the `InferenceClient` conformance callers use.
- **`InferenceRouter`** — request routing (interactive vs. background priority per the design).
- **`ModelRegistry`** + **`HardwareTierDetector`** — capability → best-installed-model mapping with manifest (signature/checksum) verification.
- **`MemoryGovernor`** — load/unload and memory caps.
- **OCR (P1-13):** `VisionOCRProvider`/`VisionAdapter` — a real Vision-framework OCR endpoint with text geometry.
- **Embeddings (P1-14):** `NLEmbeddingProvider` + `CosineSearch` — the embed endpoint backing the semantic-matching rung.
- **Placeholders:** `CoreMLAdapter` and `FoundationModelsAdapter` exist as adapter seams but no classify/extract/generate models are wired yet.

Runs in-process today — `Services/InferenceService` is a ping self-check skeleton; the real `Inference.xpc` boundary is pending ([../services/inference-service.md](../services/inference-service.md)).

## Design (`docs/ARCHITECTURE.md` §7.2)

Request routing with priority queues (interactive autofill matching preempts background ingestion OCR), a model registry mapping capability → best-installed-model-for-hardware-tier, per-engine adapters (Vision/Core ML/FoundationModels), and a memory governor for load/unload and caps.

## Allowed imports

Foundation, `InferenceAPI`, `Platform`, Vision/NaturalLanguage/Core ML (Infra-tier privilege).
