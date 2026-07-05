---
type: engine
title: InferenceHost
description: The XPC client + model registry/adapters implementing InferenceAPI — signature-and-checksum-verified model loading only. Currently a placeholder stub.
tags: [engine, infrastructure-layer, ml, xpc-client, stub]
implementation_status: scaffolded
---

# InferenceHost

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the XPC client plus model registry/adapters (Vision, Core ML, FoundationModels) implementing `InferenceAPI` ([../packages/inference-api.md](../packages/inference-api.md)) — itself also still a stub, so this package currently has no protocol to conform to yet either. Models load only after signature + checksum verification; an unverified model path must be refused, not warned about.

## Current state

`Packages/InferenceHost/Sources/InferenceHost/InferenceHost.swift` is a 4-line placeholder. No model registry, adapter, or XPC-client wiring exists yet.

## Design intent (`docs/ARCHITECTURE.md` §7.2)

Implements the `Inference.xpc` side described in [../services/inference-service.md](../services/inference-service.md): request routing with priority queues (interactive autofill matching preempts background ingestion OCR), a model registry mapping capability → best-installed-model-for-hardware-tier, per-engine adapters (Vision/Core ML/FoundationModels), and a memory governor for load/unload and caps.

## Allowed imports

Foundation, `InferenceAPI`, `Platform`.
