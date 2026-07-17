# P1-19 — Wire App Memory-Pressure Source to Viewer Tile Cache

**Epic:** E3 · **Primary package:** `App` · **Complexity:** S · **Priority:** Medium

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
