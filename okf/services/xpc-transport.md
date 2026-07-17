---
type: service
title: XPC Transport Protocol
description: How the main app and services actually talk — the typed envelope, one shared @objc interface, IOSurface for bitmaps, and codegen'd DTOs.
tags: [xpc, transport, protocol, ipc]
implementation_status: partial
---

# XPC Transport Protocol

The concrete mechanism behind every arrow in [../architecture/process-topology.md](../architecture/process-topology.md). Fully implemented in `Packages/Platform/Sources/Platform/XPC/` — see [../packages/platform.md](../packages/platform.md) for the type-by-type breakdown (`XPCClient`, `XPCServiceHost`, `XPCEnvelopeExchanging`, `XPCEnvelope`, `XPCTransportError`).

## The shape of a call

1. Caller builds a typed `Request` DTO (`Codable & Sendable`), passes it to `XPCClient<Request, Response>.send(_:timeout:)`.
2. The client wraps it in an `XPCEnvelope` (route name + interface version + JSON payload) and calls the single shared `@objc` method `exchange(_:reply:)` — every route in the app goes through this one method, not a bespoke `@objc` protocol per feature (ADR-002).
3. The listener side (`XPCServiceHost`) decodes the envelope, checks the route and interface version match, dispatches to a handler closure, and encodes the response (or a typed `XPCTransportError`) back into an `XPCResponseEnvelope`.
4. Bulk pixel data (rendered page tiles) skips the JSON envelope entirely and goes through `sendSurface(_:tag:)` — a real `IOSurface` handed across the process boundary as shared memory, zero-copy.

## Where DTOs come from

`Schemas/xpc-dtos.yml` is the single source of truth; `Scripts/codegen.sh` generates `Packages/Platform/Sources/Platform/XPC/Generated/XPCDTOs.generated.swift` from it. Today the schema defines exactly one pair, `PingRequest`/`PingResponse` — the P0-05 skeleton's self-check payload. Adding a real route (e.g. a render-tile request) means adding it to the schema and regenerating, never hand-editing the generated file (`codegen.sh --check` in CI catches drift). Changing the schema is itself a frozen-seam change requiring an ADR (root CLAUDE.md §3.6).

## Versioning

Every interface is versioned from day one (`XPCInterfaceVersion.current = "v1"`). A version mismatch between client and host produces a typed `.versionMismatch(local:remote:)` error rather than a crash or silent misparse.

## What's proven, what isn't

The transport contract itself is proven via same-process anonymous `NSXPCListener`s (`XPCTransportTests`, and `Services/DocEngineService`'s self-check — see [doc-engine-service.md](doc-engine-service.md)) — this is genuine XPC IPC, just not yet across two separately-launched OS processes. Real cross-process connection requires a proper `.xpc` bundle registered by bundle identifier (handled by `xpcproxy`) — still pending; P0-07 shipped the shell app with the engine wired in-process instead. Ad-hoc alternatives (`NSKeyedArchiver` on an `NSXPCListenerEndpoint`, an ad-hoc `machServiceName` listener between two independent processes) were tried and empirically confirmed not to work — see ADR-002.
