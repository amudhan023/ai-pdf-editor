# P0-05 — XPC Transport Layer & DTO Codegen (Freeze Point)

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
