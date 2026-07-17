# P1-19 — Wire App Memory-Pressure Source to Viewer Tile Cache

**Epic:** E3 · **Primary package:** `App` · **Complexity:** S · **Priority:** Medium

**Owner:** claude-agent · **Branch:** task/P1-19-viewer-memory-pressure-wiring · **Claimed:** 5fb88d3

## Goal
Under real system memory pressure, the viewer's tile cache actually evicts down instead of holding its full byte budget.

## Background
P1-01 built `TileCache.respondToMemoryPressure(retaining:)` and `DocumentViewModel.handleMemoryPressure()` as the call-in point, but deliberately left the `DispatchSource.makeMemoryPressureSource` composition-root wiring out of scope (primary package was `Packages/DocumentSession`, not `App`). See that package's `CLAUDE.md` tiling-architecture note for why the source can't live on the actor itself (handler fires off-actor).

## Requirements
- `App`'s composition root creates a `DispatchSourceMemoryPressure` (warning/critical) and calls `DocumentViewModel.handleMemoryPressure()` from its handler.
- No new entitlement needed (this is a standard GCD API, not sandboxed differently).

## Dependencies
- P1-01 (done).

## Files Likely Affected
- `App/Sources/Vaultform/AppDelegate.swift` (or wherever `DocumentViewModel` is constructed).

## Acceptance Criteria
- A simulated memory-pressure event (test harness or manual `memory_pressure` tool) measurably shrinks `TileCache.currentByteCount` toward the configured retain fraction.

## Definition of Done
- Global DoD (tasks/README.md), plus: manual verification steps documented in the PR since `App` has no XCTest target pattern for GCD memory-pressure simulation yet.

## Testing Requirements
- If feasible, a seam that lets a test inject a fake pressure trigger; otherwise document the manual verification performed.

## Documentation Updates
- `App`'s composition-root code comment noting the wiring, if `App` doesn't have its own `CLAUDE.md` yet.

## Journal

- `App/Sources/Vaultform/MemoryPressureMonitor.swift`: owns the `DispatchSourceMemoryPressure` (warning+critical, utility queue — GCD justified: no async-sequence equivalent exists for this signal); handler hops to the main actor and calls `DocumentViewModel.handleMemoryPressure()`. Wired in `AppDelegate.init`.
- Activation happens in `init`, not a separate `start()`: libdispatch crashes on release of a never-activated source (found the hard way — the first test run crashed the XCTest process in `deinit`).
- Test seam per this task's Testing Requirements: `simulatePressureEvent()` invokes the same closure the GCD source would. `MemoryPressureMonitorTests` covers (1) handler invocation and (2) the acceptance criterion end-to-end minus the kernel signal: a pressure event routed exactly as `AppDelegate` wires it shrinks a populated `TileCache.currentByteCount` below its pre-pressure level (budget sized so the 25% retain target forces observable eviction).
- Manual verification of the real kernel signal (`sudo memory_pressure -S -l warn`) not performed — needs root; the seam test covers everything downstream of the source firing, and the source setup itself is 3 lines of standard GCD.
