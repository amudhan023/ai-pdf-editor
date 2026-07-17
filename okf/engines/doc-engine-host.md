---
type: engine
title: DocEngineHost
description: The PDFium adapter implementing PDFEngineAPI's DocumentLifecycle + PageRenderer — the only package allowed to link the PDF engine. Text editing, forms, annotations, and save still unbuilt.
tags: [engine, infrastructure-layer, pdfium, xpc-client]
implementation_status: partial
---

# DocEngineHost

**Purpose:** the XPC client plus PDFium adapter implementing `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)). Explicitly **the only package in the repo permitted to link the PDF engine**. Designed to run hostile-input parsing inside `DocEngine.xpc` ([../services/doc-engine-service.md](../services/doc-engine-service.md)).

## Current state (P0-03, P0-06)

- **`PDFiumEngine`** (`PDFiumEngine.swift`) — an `actor` conforming to `DocumentLifecycle` + `PageRenderer`: real PDFium open/close, page count/metadata, and tiled rendering, against the pinned PDFium binaries vendored in `ThirdParty/pdfium` (P0-03, resolving escalation E-004). A `RenderLatencyBench` executable target backs the perf budget.
- **Not yet implemented:** `TextEditor`, `PageOrganizer`, `AnnotationStore`, `FormModel` conformances, and save (incremental-update / full-rewrite) — the "largest single build effort in the project" (`docs/ARCHITECTURE.md` §10.1) is still ahead.
- **Boundary caveat:** `App/` wires `PDFiumEngine` *in-process* today ([../services/doc-engine-service.md](../services/doc-engine-service.md)); the real `DocEngine.xpc` process split needs a proper `.xpc` bundle in an Xcode app target and is filed as follow-up scope.

## Design (`docs/ARCHITECTURE.md` §3.2, §10.1)

The PDFium wrapper: incremental parse, tiled rendering (via `IOSurface` shared memory across XPC — see [../services/xpc-transport.md](../services/xpc-transport.md)), content-stream editing, annotation serialization, AcroForm read/write, save via incremental-update or full-rewrite mode. Must never touch the network, the vault, or any file it wasn't explicitly handed a security-scoped handle for. The real text-editing layer is this product's competitive moat ([../architecture/technology-choices.md](../architecture/technology-choices.md)).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`, plus the PDFium shim (`CPDFium`) — this package's exclusive privilege.
