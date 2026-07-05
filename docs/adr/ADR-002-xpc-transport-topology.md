# ADR-002 — XPC Transport Topology & DTO Codegen (Freeze Point)

**Status:** Accepted · **Task:** P0-05

## Context
ARCHITECTURE.md §3.3 requires cross-process communication to be "typed, versioned, capability-scoped," interfaces "defined as Swift protocols with Codable DTOs; no `NSSecureCoding` custom classes beyond the boundary," bulk pixel data via `IOSurface`, and all XPC APIs versioned from day 1 (`v1` suffix). REPO_STRUCTURE.md principle 7 requires DTOs generated from a single `Schemas/` source so both sides of every process boundary stay in lockstep. This is the plumbing every later service task (P0-06 DocEngine, P1-08 Vault, P1-12 Inference) builds on — landing it wrong here means three separate re-plumbings later.

## Decision

### One generic envelope, not one `@objc` protocol per DTO pair
`NSXPCConnection`/`NSXPCInterface` fundamentally require an `@objc` protocol for the wire-level interface — there is no way to hand it a plain `Codable` Swift protocol directly. Rather than hand-writing a new `@objc` protocol for every DTO pair (ping, render-page, fill-request, ...), `Packages/Platform/Sources/Platform/XPC/` defines exactly **one** `@objc` protocol, `XPCEnvelopeExchanging` (`exchange(_:reply:)` + `sendSurface(_:tag:reply:)`), and a generic `XPCClient<Request: Codable, Response: Codable>` / `XPCServiceHost<Request: Codable, Response: Codable>` pair that encode/decode Codable DTOs into/out of an `XPCEnvelope` (`route`, `interfaceVersion`, `payload: Data`) carried as the `exchange` method's opaque `Data` argument. This satisfies ARCHITECTURE.md §3.3's "Codable DTOs; no NSSecureCoding custom classes beyond the boundary" at the *developer-facing* layer — every future service task writes `XPCClient<MyRequest, MyResponse>`, never a new `@objc` protocol — while giving `NSXPCConnection` the one concrete `@objc` interface it actually needs underneath.

### Bulk pixel data: `IOSurface`, not the envelope
`sendSurface(_:tag:reply:)` is a second, separate method on the same protocol taking a raw `IOSurface` parameter directly — real shared memory across the process boundary (verified: a mutation made by the receiving side is visible to the sending side's own surface reference without any further copy, `XPCTransportTests.testIOSurfaceRoundTripIsRealSharedMemory`). This is deliberately *not* funneled through the JSON envelope (which would force a copy through `Data`, defeating the entire point of `IOSurface` for page-tile bitmaps per ARCHITECTURE.md §3.3).

### Versioning
`XPCEnvelope.interfaceVersion` carries the `v1`-style string from `Schemas/xpc-dtos.yml`'s `interfaceVersion` key (codegen emits it as `XPCInterfaceVersion.current`). A mismatch is a typed `XPCTransportError.versionMismatch(local:remote:)` — critically, **framed from the receiver's perspective** in both directions (a mismatch detected client-side reports `local` = the client's own version; a mismatch detected host-side and relayed back reports `local` = the *client's* version, `remote` = the host's — not the host's own frame of reference, which reads backwards to whoever receives the error). Got this wrong once during implementation (host encoded it from its own perspective and relayed it verbatim) — `XPCTransportTests.testVersionMismatchIsTypedError` catches the regression.

### Crash/timeout/reconnect
`XPCClient` drops its cached `NSXPCConnection` the moment `interruptionHandler`/`invalidationHandler` fires, surfacing the in-flight call's failure as `.serviceCrashed` — it does **not** auto-retry the failed call itself (only the caller knows whether a retry is safe/idempotent), but the *next* `send()` transparently builds a fresh connection. A `DispatchWorkItem`-based timeout races the reply on every call. Both are proven via `XPCCrashRecoveryIntegrationTests` (Platform package) and `XPCTransportTests.testTimeoutFiresWhenHandlerNeverReplies`.

### Codegen
`Schemas/xpc-dtos.yml` → `Scripts/codegen.sh` → `Packages/Platform/Sources/Platform/XPC/Generated/XPCDTOs.generated.swift`, via a hand-written parser (`Scripts/_xpc_codegen.py`) for a deliberately constrained YAML subset (documented in `Schemas/README.md`) rather than a PyYAML dependency (CLAUDE.md §17: default answer to a new dependency is no, and this is ~80 lines of straight-line parsing for a shape only this repo produces). `codegen.sh --check` diffs the committed generated file against a fresh regeneration and fails on drift — wired into CI's `repo-checks` job.

## A real, empirically-confirmed limitation: no cross-process XPC without an app bundle yet
While implementing `Services/DocEngineService`'s skeleton (this task's "echoes a ping DTO end-to-end" requirement), two independent things were tried and confirmed *not* to work for establishing XPC between two ad-hoc, independently-launched processes (i.e., without a proper `.xpc` bundle embedded in an app target):

1. **Archiving `NSXPCListenerEndpoint` to hand to a child process out-of-band** (e.g., over its stdout pipe): `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)` throws at runtime — `NSXPCListenerEndpoint` "may only be encoded by an NSXPCCoder." An endpoint can only be transferred *as a parameter of an active XPC call*, not archived arbitrarily.
2. **`NSXPCListener(machServiceName:)` / `NSXPCConnection(machServiceName:)` between two independently-spawned, non-launchd-registered processes**: the connecting side does not successfully connect (observed: silent hang or a `SIGTRAP` crash on the dynamic proxy cast, no successful round-trip, across repeated attempts). Real Mach service registration/lookup requires the service name to be pre-declared to `launchd` (a `LaunchAgent`/`LaunchDaemon` plist, or — the actual production path here — an embedded `.xpc` bundle in an app target, which `xpcproxy` registers by bundle identifier automatically).

**Consequence:** genuine cross-process XPC connectivity for this app is only provable once P0-07 lands the real Xcode app target with `Services/*` embedded as proper `.xpc` bundles. Until then:
- The transport *contract* (envelope negotiation, versioning, timeout, crash-detection-and-reconnect, `IOSurface` passing) is fully proven via `NSXPCListener.anonymous()` same-process round trips (`XPCTransportTests`, `XPCCrashRecoveryIntegrationTests`) — this is genuine XPC IPC machinery (real serialization, real separate connection objects), just not a different OS process.
- `Services/DocEngineService` is a real, standalone, separately-launchable/killable SwiftPM executable (`DocEngineServiceIntegrationTests` spawns and kills it as a real `Process`) proving Platform's XPC types link and run correctly outside the test process, via an in-process self-check on startup — not a claim that another process can connect *into* it yet.
- This is the same category of finding as `E-004` (PDFium build infeasibility): a genuine environment/platform constraint, not a code defect, reported honestly rather than worked around with something fragile.

## Measured round-trip latency baseline (Definition of Done)
`Scripts/bench.sh xpc-latency` (200 same-process anonymous-listener round trips via `Packages/Platform`'s `XPCLatencyBench` executable target), measured on this development machine:

| Percentile | Latency |
|---|---|
| p50 | ~0.06–0.13 ms |
| p90 | ~0.07–0.19 ms |
| max (200 samples) | ~0.11–0.47 ms |

This excludes real cross-process Mach IPC overhead (see the limitation above) — it is a regression baseline for the envelope encode/decode + dispatch path itself, not a production cross-process latency figure. A real cross-process baseline is a P0-07 follow-up once the app bundle exists.

## Consequences
- Any change to `XPCEnvelope`, `XPCEnvelopeExchanging`, or `Schemas/xpc-dtos.yml`'s grammar is a frozen-seam change: superseding ADR + `[INTEGRATION]`-marked PR (root CLAUDE.md §3.6/§21).
- Every future service (`DocEngineService`, `InferenceService`, `VaultService`) adds DTOs to `Schemas/xpc-dtos.yml` and gets an `XPCClient`/`XPCServiceHost` pair for free — it does not define its own `@objc` protocol.
- P0-06/P0-07 must re-validate the cross-process limitation noted above once the real app bundle exists, and update this ADR (or a superseding one) with the actual measured cross-process latency baseline at that point.
