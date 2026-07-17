---
type: engine
title: InferenceHost
description: The XPC client + model registry/adapters implementing InferenceAPI — signature-and-checksum-verified model loading only. Currently a placeholder stub.
tags: [engine, infrastructure-layer, ml, xpc-client, stub]
implementation_status: partial
---

# InferenceHost

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the XPC client plus model registry/adapters (Vision, Core ML, FoundationModels) implementing `InferenceAPI` ([../packages/inference-api.md](../packages/inference-api.md)) — itself also still a stub, so this package currently has no protocol to conform to yet either. Models load only after signature + checksum verification; an unverified model path must be refused, not warned about.

## Current state

Substantially implemented (P1-12, P1-13): `ModelRegistry` (signature+checksum verification before load), `InferenceRouter`, `MemoryGovernor`, `HardwareTierDetector`, adapters for Vision (`VisionAdapter`/`VisionOCRProvider` — real OCR), Core ML, and FoundationModels, plus an `Embed/` provider. XPC-client wiring across a real process boundary is still pending (same `.xpc` bundle constraint every service documents).

## Design intent (`docs/ARCHITECTURE.md` §7.2)

Implements the `Inference.xpc` side described in [../services/inference-service.md](../services/inference-service.md): request routing with priority queues (interactive autofill matching preempts background ingestion OCR), a model registry mapping capability → best-installed-model-for-hardware-tier, per-engine adapters (Vision/Core ML/FoundationModels), and a memory governor for load/unload and caps.

## Allowed imports

Foundation, `InferenceAPI`, `Platform`.
