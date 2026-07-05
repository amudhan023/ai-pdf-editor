---
type: engine
title: DocEngineHost
description: The XPC client + PDFium adapter implementing PDFEngineAPI — the only package allowed to link the PDF engine. Currently a placeholder stub.
tags: [engine, infrastructure-layer, pdfium, xpc-client, stub]
implementation_status: scaffolded
---

# DocEngineHost

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the XPC client plus PDFium adapter implementing `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)). Explicitly **the only package in the repo permitted to link the PDF engine**. Runs hostile-input parsing inside `DocEngine.xpc` ([../services/doc-engine-service.md](../services/doc-engine-service.md)).

## Current state

`Packages/DocEngineHost/Sources/DocEngineHost/DocEngineHost.swift` is a 4-line placeholder. No PDFium binding, no `PDFEngineAPI` conformance, and no XPC-client wiring exist yet — `Services/DocEngineService`'s current `main.swift` proves only the transport layer works, not this package's job (parsing/rendering/editing).

## Design intent (`docs/ARCHITECTURE.md` §3.2, §10.1)

The PDFium wrapper: incremental parse, tiled rendering (via `IOSurface` shared memory across XPC — see [../services/xpc-transport.md](../services/xpc-transport.md)), content-stream editing, annotation serialization, AcroForm read/write, save via incremental-update or full-rewrite mode. Must never touch the network, the vault, or any file it wasn't explicitly handed a security-scoped handle for. This package's build effort is called out in `docs/ARCHITECTURE.md` §10.1 as "the largest single build effort in the project" — the real text-editing layer this product's competitive moat depends on ([../architecture/technology-choices.md](../architecture/technology-choices.md)).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`.
