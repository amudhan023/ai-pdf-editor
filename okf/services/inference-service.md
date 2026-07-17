---
type: service
title: Inference.xpc
description: The sandboxed ML inference service — today a ping self-check skeleton executable; the real registry/router logic lives in the InferenceHost package.
tags: [service, xpc, ml, inference]
implementation_status: scaffolded
---

# Inference.xpc — `Services/InferenceService`

## Current state (P1-12, P1-17)

`Services/InferenceService/Sources/InferenceService/main.swift` is a thin skeleton on the same pattern as `DocEngineService`'s (P0-05): it hosts an `XPCServiceHost<PingRequest, PingResponse>` on an anonymous listener and sends itself a ping, proving `Platform`'s transport types link and run in a standalone executable. It is wired into CI's services job (P1-17). What it **cannot** yet prove: a genuine cross-process connection from another process — that needs a real `.xpc` bundle target (see ADR-002 and [../architecture/process-topology.md](../architecture/process-topology.md)).

The registry/router/memory-governor logic this service will eventually host already exists and is tested in the `InferenceHost` package ([../engines/inference-host.md](../engines/inference-host.md)) — this executable stays a linkage/wiring proof only.

## Trust posture (design)

Semi-trusted — processes content already extracted from documents (not raw hostile file bytes). No network entitlement; read-only access to the model directory; memory-capped. In-flight inference is retried on crash rather than the whole document/session being lost.

## Design (`docs/ARCHITECTURE.md` §7.2)

```
App (Inference Client, typed async API)
  → Request Router + priority queues
       → Vision adapter | Core ML adapter (ANE/GPU/CPU plan) | FoundationModels adapter
       Model Registry (signature + checksum verify) ← Model Pack Store (read-only, signed)
       Memory Governor (load/unload, caps)
```

- **Typed endpoints, not "run a model":** callers ask for `embed(labels:context:)`/`ocr(...)`/`classify(...)`/`generate(...)`, never name a model file — the registry maps capability to the best installed model for the current hardware tier.
- **Model packs** are signature-and-checksum-verified before load; an unverified pack is refused outright, never a soft warning.
- **Interactive vs. background queues:** autofill matching preempts batch ingestion OCR, to hit the < 3s autofill budget.

The typed contract is `InferenceAPI` ([../packages/inference-api.md](../packages/inference-api.md)), now implemented.
