---
type: service
title: DocEngine.xpc
description: The sandboxed PDF parse/render service — hostile-input trust posture, per-document process instance. Currently a self-check skeleton.
tags: [service, xpc, pdf, sandboxing]
implementation_status: partial
---

# DocEngine.xpc — `Services/DocEngineService`

## Trust posture

**Hostile input** — parses arbitrary user PDFs/DOCX/images, the most-exploited document format category in existence. No network entitlement, no vault container access; receives only security-scoped file handles the main app explicitly passes it. Designed to run **one instance per open document**, so a malformed file only kills the render of that one window, not the whole app (see [../architecture/process-topology.md](../architecture/process-topology.md)).

## Current implementation

`Services/DocEngineService/Sources/DocEngineService/main.swift` is a thin skeleton (P0-05) — not the real PDFium-backed engine. What it actually does: builds an anonymous `NSXPCListener`, hosts an `XPCServiceHost<PingRequest, PingResponse>` on route `"ping"` that echoes a nonce, then builds an `XPCClient` against that same listener's endpoint and sends itself a ping, printing `"DocEngineService self-check: OK (...)"` to stdout on success.

Its own code comment is explicit about scope:
- **Can prove:** `Platform`'s XPC transport types compile and round-trip correctly inside a real, standalone, separately-launchable/killable executable (not just inside a test process).
- **Cannot yet prove:** a genuine connection *into* this process from a different, independently-spawned process — that needs launchd/bundle registration (P0-07), confirmed empirically not to work via ad-hoc mechanisms (see [xpc-transport.md](xpc-transport.md)).

## Not yet built

The actual `DocEngineHost` integration (PDFium wrapper, incremental parse, tiled rendering, content-stream editing, AcroForm read/write) — see [../engines/doc-engine-host.md](../engines/doc-engine-host.md), itself still a stub. The real `.xpc` bundle registration into the app target.

## A concurrency gotcha worth knowing (from the code's own comments)

Top-level `main.swift` code stays synchronous so `RunLoop.main.run()` can block forever — an async main context can't call it. Mixing a blocking `DispatchSemaphore.wait()` on the main thread with an unstructured `Task {}` deadlocks (the task never gets scheduled); the working pattern is to enter the run loop immediately and let the async self-check print whenever it completes.
