---
type: service
title: Inference.xpc
description: The planned sandboxed ML inference service — model registry, typed endpoints, memory governor. Not yet scaffolded.
tags: [service, xpc, ml, inference, planned]
implementation_status: planned
---

# Inference.xpc — `Services/InferenceService`

## Current state

`Services/InferenceService/` contains only a `README.md` — no `Sources/` directory, no target, nothing runnable yet. Everything below is design intent from `docs/ARCHITECTURE.md` §7.2, not implemented behavior.

## Trust posture (planned)

Semi-trusted — processes content already extracted from documents (not raw hostile file bytes). No network entitlement; read-only access to the model directory; memory-capped. In-flight inference is retried on crash rather than the whole document/session being lost.

## Design intent

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

This is the future implementation target for `InferenceAPI` ([../packages/inference-api.md](../packages/inference-api.md)) and `InferenceHost` ([../engines/inference-host.md](../engines/inference-host.md)) — both themselves still stubs.
