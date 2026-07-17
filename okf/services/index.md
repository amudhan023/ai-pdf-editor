---
type: index
title: Services Index
description: The three sandboxed .xpc bundle targets and the transport protocol between them.
tags: [services, xpc, overview]
---

# Services

Thin executables over `Packages/*` — each is the process boundary for one trust domain (see [../architecture/process-topology.md](../architecture/process-topology.md)).

| Service | Trust posture | Status |
|---|---|---|
| [doc-engine-service.md](doc-engine-service.md) | Hostile input (parses arbitrary PDFs) | Skeleton — self-check `main.swift` only |
| [inference-service.md](inference-service.md) | Semi-trusted (processes extracted content) | Skeleton — self-check `main.swift` only (P1-12); real logic in `InferenceHost` |
| [vault-service.md](vault-service.md) | Most privileged (sole owner of vault DB/keys) | Skeleton — self-check `main.swift` only (P1-08); real logic in `VaultStore` |
| [xpc-transport.md](xpc-transport.md) | N/A — the wire protocol all three use | Implemented (`Platform` package) |
