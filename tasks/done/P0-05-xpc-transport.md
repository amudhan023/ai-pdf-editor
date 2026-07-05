# P0-05 — XPC Transport Layer & DTO Codegen (Freeze Point)

**Owner:** claude-code · **Branch:** task/P0-05-xpc-transport · **Claimed:** 729bbdd

**Epic:** E1 · **Primary package:** `Packages/Platform` + `Schemas/` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
One reusable, typed XPC transport (Codable DTOs, versioned interfaces, IOSurface payload support) plus codegen from `Schemas/xpc-dtos.yml`, used by all three services.

## Background
ARCHITECTURE.md §3.3: capability-scoped, versioned XPC with generated DTOs keeps both sides of every process boundary in lockstep (REPO_STRUCTURE.md principle 7). This is the plumbing every service task builds on.

## Requirements
- Generic client/listener wrappers: async request/response over `NSXPCConnection`, cancellation, timeout, service crash → typed error + auto-reconnect policy.
- `Scripts/codegen.sh`: schema → Swift DTOs (+ `--check` drift mode for CI).
- IOSurface passing utility for bitmap payloads; interface versioning convention (`v1`).
- Skeleton `Services/DocEngineService` target that echoes a ping DTO end-to-end (proves wiring; render logic comes in P0-06).

## Dependencies
- P0-01, P0-02.

## Files Likely Affected
- `Packages/Platform/Sources/XPC/**`; `Schemas/xpc-dtos.yml`; `Scripts/codegen.sh`; `Services/DocEngineService/**` (skeleton).

## Acceptance Criteria
- Integration test: app process ↔ XPC service round-trips typed DTO + an IOSurface; kills the service mid-call and receives typed failure + successful retry.
- Codegen drift check fails CI when schema and generated code diverge.

## Definition of Done
- Global DoD, plus: ADR-002 updated with measured round-trip latency baseline.

## Testing Requirements
- Unit tests for envelope/version negotiation; crash-recovery integration test; latency microbenchmark recorded in `bench.yml` baseline.

## Documentation Updates
- `Packages/Platform/CLAUDE.md` XPC usage guide; Schemas/README.

---
## Journal

**Plan:** one generic `XPCClient<Request,Response>`/`XPCServiceHost<Request,Response>` pair over a single shared `@objc` envelope protocol (`XPCEnvelopeExchanging`), rather than a new `@objc` protocol per DTO — see ADR-002 for the full rationale. DTOs generated from `Schemas/xpc-dtos.yml` via a hand-written parser (no PyYAML dependency). `Services/DocEngineService` as the "echoes a ping DTO" skeleton.

**Done:**
- `Packages/Platform/Sources/Platform/XPC/`: `XPCEnvelope`/`XPCResponseEnvelope`, `XPCTransportError` (Codable, so a host-detected error can travel back to the client), `XPCEnvelopeExchanging` (`exchange` + `sendSurface`), `XPCClient` (async `send`, `NSLock`-guarded connection cache, drop-and-rebuild-on-invalidate reconnect policy, `DispatchWorkItem` timeout race, `sendSurface` for `IOSurface`), `XPCServiceHost` (`NSXPCListener` wrapper, generic-parameter-free exported object per the "generic classes can't have `@objc` members referencing their own generic params" constraint).
- `Schemas/xpc-dtos.yml` populated (`PingRequest`/`PingResponse`, `interfaceVersion: v1`); `Schemas/README.md` documents the constrained grammar. `Scripts/_xpc_codegen.py` (hand-written parser, no new dependency per CLAUDE.md §17) + `Scripts/codegen.sh` real implementation (regenerate / `--check` drift mode, proven both ways: a planted stale-generated-file diff correctly fails `--check`).
- `Services/DocEngineService`: own SwiftPM package (not yet the real `.xpc` bundle — that's P0-07's job, see below). `main.swift` runs a real in-process self-check via the same `XPCClient`/`XPCServiceHost` types, proving they link and run in a genuinely separate, killable process. `DocEngineServiceIntegrationTests` spawns the compiled binary as a real `Process`, confirms the self-check output, and kills it.
- Tests: `XPCTransportTests` (ping round-trip, version-mismatch negotiation, remote-throw surfacing, timeout, real `IOSurface` shared-memory round-trip — all via `NSXPCListener.anonymous()`, genuine XPC IPC, same process), `XPCCrashRecoveryIntegrationTests` (a listener that invalidates its own connection instead of replying on a sentinel request — proves `.serviceCrashed` + successful reconnect-and-retry on the same client instance).
- `Scripts/verify-integration.sh`'s naming convention (P0-15, `*ConformanceTests`/`*IntegrationTests`) picks up `XPCCrashRecoveryIntegrationTests` automatically; `DocEngineServiceIntegrationTests` is covered by a new CI `services` job (`Services/` isn't part of the `Packages/*` matrix `detect-changes` scans).
- `Scripts/bench.sh xpc-latency` (new suite) + `Packages/Platform`'s `XPCLatencyBench` executable target: measured baseline recorded in the new `docs/adr/ADR-002-xpc-transport-topology.md`.
- Docs: ADR-002 (new — no prior ADR-002 existed despite being referenced by name elsewhere; this task is its origin), `Packages/Platform/CLAUDE.md` (XPC usage guide + two real gotchas hit during implementation), `Schemas/README.md`, `Services/DocEngineService/README.md`.
- Added `IOSurface` to `Scripts/import-allowlist.txt` for `Platform` (system framework, not a new third-party dependency — same precedent as `PolicyKit`'s `CryptoKit` addition, no ADR needed per CLAUDE.md §17).

**Two real bugs found and fixed via actual test runs, not assumed correct:**
1. `NSXPCListener.delegate` is `weak` — a test helper that let its `XPCServiceHost` fall out of scope after `resume()` caused every subsequent connection to silently get no delegate (manifested as `.serviceCrashed` on calls that should have succeeded). Fixed by retaining hosts explicitly in tests; documented as a gotcha in `Platform/CLAUDE.md` since it'll bite the next person too.
2. A host-detected `versionMismatch` was encoded from the *host's* frame of reference (`local` = host's version) and relayed to the client verbatim, which reads backwards once received (`XCTAssertEqual` catching `local`/`remote` swapped). Fixed by reframing host-side encoding to the client's perspective before sending.

**A third: blocking the main thread with `DispatchSemaphore.wait()` before an unstructured `Task {}` gets scheduled deadlocks the process** (confirmed twice, in both `Services/DocEngineService/main.swift` and `XPCLatencyBench/main.swift`) — the Task never started running. Fixed both by entering `RunLoop.main.run()` (or pumping it in short bursts) instead of blocking first. Documented in `Platform/CLAUDE.md` since it's exactly the kind of non-obvious constraint this repo's comment policy asks for.

**A real, empirically-confirmed platform limitation (own subsection in ADR-002, same honest-reporting posture as `E-004`):** genuine cross-process XPC between two ad-hoc, independently-launched, non-app-bundled processes does not work on this platform — tried and confirmed failing twice: (1) archiving an `NSXPCListenerEndpoint` via `NSKeyedArchiver` to hand to a child process throws at runtime ("may only be encoded by an NSXPCCoder"); (2) `NSXPCListener(machServiceName:)`/`NSXPCConnection(machServiceName:)` between two unprivileged, non-launchd-registered processes does not connect (hangs or crashes, no successful round-trip, across repeated attempts). Real cross-process XPC requires either launchd registration or — the actual production path — a proper `.xpc` bundle embedded in an app target, which is P0-07's job. Consequence for this task's acceptance criteria: the crash-recovery contract and the IOSurface/ping round-trip are proven for real via `NSXPCListener.anonymous()` (genuine XPC IPC, same process) rather than via a literally separate process; `Services/DocEngineService` proves the executable links/runs standalone but not that another process can connect into it yet. Flagging this rather than silently declaring the literal "kills the service" wording fully met.

**Security self-audit:** no vault/document data path touched; no network APIs; no logging of content. `IOSurface`/`Data` payloads passed are test/bench-only synthetic bytes, never real content. `none` beyond the standard XPC-boundary-hygiene invariants this package itself defines.

**Acceptance criteria status:**
- "Integration test: app process ↔ XPC service round-trips typed DTO + an IOSurface": ✅ for the DTO+IOSurface round-trip contract (`XPCTransportTests`), via genuine same-process XPC IPC — not literally "app process" since no app exists yet (P0-07).
- "...kills the service mid-call and receives typed failure + successful retry": ✅ for the contract (`XPCCrashRecoveryIntegrationTests`, via real `NSXPCConnection` invalidation) — ⚠️ not via a literally separate OS process being killed, for the platform-limitation reason above. `DocEngineServiceIntegrationTests` does kill a real separate process, but that test doesn't hold a live XPC connection into it (not achievable yet).
- "Codegen drift check fails CI when schema and generated code diverge": ✅ proven directly (planted a stale generated file, `--check` failed with the exact expected diff, reverted).
- "ADR-002 updated with measured round-trip latency baseline": ✅ — ADR-002 created (didn't exist previously) with the baseline table from `Scripts/bench.sh xpc-latency`.
