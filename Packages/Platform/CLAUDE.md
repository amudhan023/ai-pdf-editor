# Platform

**Purpose:** OS service wrappers: XPC transport, Keychain, LocalAuthentication, file coordination, domain event bus. Infrastructure tier.

**Allowed imports:** Foundation, IOSurface (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh Platform` (build + tests + boundary lint), `Scripts/verify-integration.sh Platform` (the `*ConformanceTests`/`*IntegrationTests` subset).

**XPC usage (P0-05/ADR-002 — frozen seam, see that ADR before touching `XPC/`):**
- One generic pair per DTO type: `XPCClient<Request: Codable & Sendable, Response: Codable & Sendable>` (caller side) and `XPCServiceHost<Request, Response>` (listener side) — never write a new `@objc` protocol per feature; `XPCEnvelopeExchanging` is the one shared low-level interface underneath both.
- Add new DTOs in `Schemas/xpc-dtos.yml`, run `Scripts/codegen.sh`, commit the regenerated `XPC/Generated/XPCDTOs.generated.swift`. `codegen.sh --check` (CI) fails on drift.
- Bulk pixel data goes through `XPCClient.sendSurface(_:tag:)`/`XPCServiceHost`'s `surfaceHandler` (real `IOSurface`, zero-copy) — never through the JSON envelope.
- `NSXPCListener.delegate` is `weak`: whatever retains your `XPCServiceHost` (or a custom delegate) must outlive the listener, or incoming connections silently get no delegate to accept them. Same failure mode bit a same-process test once (`XPCTransportTests`' helper let the host fall out of scope) — retain it explicitly if it's not a top-level/long-lived value already.
- Genuine cross-process XPC (two ad-hoc processes, no app bundle) does not work on this platform without launchd/bundle registration — confirmed empirically, written up in ADR-002. Don't try to route around it with `NSKeyedArchiver`-on-an-endpoint or an ad-hoc `machServiceName`; both were tried and fail. Wait for P0-07's real `.xpc` bundle.
- Mixing a blocking `DispatchSemaphore.wait()` on the main thread with an unstructured `Task {}` deadlocks — the task never gets scheduled. Pump `RunLoop.main.run(mode:before:)` in a loop instead if you need the main thread to wait for async work without exiting to a full `RunLoop.main.run()` forever. See `XPCLatencyBench`/`Services/DocEngineService`'s `main.swift` for the working pattern.

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
