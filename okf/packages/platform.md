---
type: package
title: Platform
description: OS service wrappers — the implemented XPC transport layer, plus planned Keychain/LocalAuthentication/file-coordination/event-bus wrappers.
tags: [package, infrastructure, xpc, transport]
implementation_status: partial
---

# Platform

**Purpose:** OS service wrappers — XPC transport, Keychain, LocalAuthentication, file coordination, domain event bus. Infrastructure tier (only Infra packages may import XPC/GRDB/CoreML per [../architecture/layered-architecture.md](../architecture/layered-architecture.md)).

## What's actually implemented: the XPC transport layer

A generic, typed pair, one instance per (Request, Response) DTO route:

- **`XPCClient<Request, Response>`** — caller side. Lazily builds/reconnects an `NSXPCConnection`; a crashed/invalidated connection is dropped immediately so the *next* `send` builds fresh, while the in-flight call fails with `.serviceCrashed` (retry safety is call-specific, not this layer's call to make). `send(_:timeout:)` encodes the request into an `XPCEnvelope`, calls the one shared `@objc` method, decodes the response, and checks interface-version match. `sendSurface(_:tag:)` is the separate zero-copy path for bitmap payloads via real `IOSurface`.
- **`XPCServiceHost<Request, Response>`** — listener side. Wraps an `NSXPCListener` (anonymous for in-process/tests, or a real named service in a shipped `.xpc` bundle) and dispatches decoded requests to a handler closure.
- **`XPCEnvelopeExchanging`** — the one `@objc` protocol every connection speaks (`exchange(_:reply:)` + `sendSurface(_:tag:reply:)`). One generic method carries every route (ADR-002) rather than a new `@objc` protocol per feature.
- **`XPCEnvelope`/`XPCResponseEnvelope`** — wire shape: route name, interface version, JSON payload; response carries exactly one of payload/error.
- **`XPCTransportError`** — typed, `Codable` (so a service-side failure can travel back inside the envelope): `.versionMismatch`, `.serviceCrashed` (client-synthesized only), `.timedOut`, `.decodingFailed`, `.remote`.
- **Generated DTOs** — `XPC/Generated/XPCDTOs.generated.swift`, codegen'd from `Schemas/xpc-dtos.yml` via `Scripts/codegen.sh`; currently only a `PingRequest`/`PingResponse` pair exists (the P0-05 skeleton). Adding new DTOs means editing the schema and regenerating — never hand-editing the generated file; `codegen.sh --check` (CI) fails on drift.

## What's proven vs. not

Proven: the transport contract via same-process anonymous `NSXPCListener`s — genuine XPC IPC, verified by `XPCTransportTests` and `Services/DocEngineService`'s self-check (see [../services/xpc-transport.md](../services/xpc-transport.md), [../services/doc-engine-service.md](../services/doc-engine-service.md)). Not yet proven: real cross-process operation between independently-spawned processes without launchd/bundle registration — confirmed empirically not to work (ADR-002); needs a proper `.xpc` bundle (task P0-07).

## Not yet built

Keychain wrapper, `LAContext` (biometric auth) wrapper, file coordination, the domain event bus (`VaultDidLock`/`DocumentSaved`/`FillCommitted`/`ProfileFieldChanged` — see [../architecture/layered-architecture.md](../architecture/layered-architecture.md)). `Platform.swift` itself is still a 4-line placeholder; only the `XPC/` subtree has real content.

## Allowed imports

Foundation, IOSurface.

## Gotchas

`NSXPCListener.delegate` is `weak` — whatever retains your `XPCServiceHost` must outlive the listener or incoming connections silently get no delegate. Mixing a blocking `DispatchSemaphore.wait()` on the main thread with an unstructured `Task {}` deadlocks — pump `RunLoop.main.run(mode:before:)` instead (see `Services/DocEngineService/Sources/DocEngineService/main.swift` for the working pattern).
