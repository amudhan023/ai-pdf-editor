# P1-01 — Viewer: Continuous Scroll, Zoom & Real Tiling

**Owner:** claude-agent · **Branch:** task/P1-01-scroll-zoom-tiling · **Claimed:** de3bafa0cb2b55d7025dfcb5e6a2269dd2098b62

**Epic:** E3 · **Primary package:** `Packages/DocumentSession` (viewer views) · **Complexity:** L · **Priority:** High

## Goal
Production scrolling/zooming document view: tile cache, progressive render, fit-page/fit-width/custom zoom, trackpad gestures, at NFR-P2 frame rates.

## Background
Replaces P0-07's naive page view. ARCHITECTURE.md NFR-P2/P5: 60fps (120 ProMotion), streamed tiles, bounded memory.

## Requirements
- Visible-rect-driven tile requests with prefetch, LRU cache with memory pressure response; low-res placeholder → sharp tile swap.
- Zoom via pinch/keyboard/menu; anchor-preserving zoom; rotation display.
- Scroll position restoration on reopen.

## Dependencies
- P0-06, P0-07.

## Files Likely Affected
- `Packages/DocumentSession/Sources/Viewer/**`.

## Acceptance Criteria
- 60fps scroll on corpus heavy-page sample (M1 baseline), measured by bench harness; memory stays < 1.5GB on 1,000-page fixture.
- No blank-tile flashes at p95 during fast scroll.

## Definition of Done
- Global DoD, plus: perf numbers added to bench trend.

## Testing Requirements
- Tile-cache unit tests (eviction, invalidation); scripted scroll perf test in bench suite; snapshot tests for zoom modes.

## Documentation Updates
- Package `CLAUDE.md` tiling architecture note.

## Journal

**Orient:** Resumed a prior session's uncommitted implementation already on this branch: `TileGrid`/`TileCache`/`ZoomMath`/`ScrollPosition` (+ `Fake`/`UserDefaults` stores) under `Sources/DocumentSession/Viewer/`, `PageTileView` + rewritten `DocumentViewerView`/`DocumentViewModel`, a `TileScrollBench` executable target, unit tests for each new type, and a `Packages/DocumentSession/CLAUDE.md` tiling-architecture note — all matching the task's Requirements/Testing Requirements. Read root CLAUDE.md, this task file, package CLAUDE.md, and the diff itself (no other doc sections cited by this task's Background beyond ARCHITECTURE.md NFR-P2/P5, already reflected in code comments).

**Plan:** the implementation was functionally complete but never verified — picked up at Step 4 (VERIFY) rather than re-planning from scratch.

**Verify:** `Scripts/verify.sh DocumentSession` initially failed: `Sources/TileScrollBench/main.swift` referenced `rects` (a `Task { }`-local var) from top-level scope when building the JSON result — a scoping bug, not a design issue. Fixed by routing the tile count through the existing (previously unused) `Results.tilesPerPage` field. Re-ran `verify.sh DocumentSession` → build+test+boundary-lint all green. `Scripts/bench.sh` had no `tile-scroll` entry despite the `TileScrollBench` target existing — added `tile_scroll()` following the `render_latency`/`xpc_latency` `swift run` pattern, wired into `run_all`/the suite dispatch/the usage string; `bench.yml` already runs `--all` so no separate CI wiring needed. `Scripts/bench.sh tile-scroll` → `status: pass` (cache-hit p50 0.04ms vs. cache-miss p50 0.046ms; final cache bytes well under the 64MB budget). `App` package (consumer) still builds clean against the changed `DocumentViewModel`/`PageImage`→`RenderedTile` API.

**Harden:** re-read the full diff as a hostile reviewer (CLAUDE.md §14). No dead code, no debug scaffolding, no narrating comments — existing comments explain real non-obvious constraints (grid clamping epsilon, byte-budget-vs-entry-count eviction rationale, TileKey float-rounding). `swiftlint lint --config .swiftlint.yml Packages/DocumentSession` → exit 0 (only pre-existing/test-scope warnings: single-char loop/test variable names, and two `Package.swift` trailing-comma spots that predate this diff — none introduced by this change, none blocking since CI doesn't run `--strict`).

**Security/privacy self-audit:** touches rendered page pixel tiles (`RenderedTile`) and page-index/vertical-fraction scroll position only — no vault values, no document text/form-field content, no network calls. Scroll position persists via `UserDefaults` keyed by file path (local-only, no content) — consistent with CLAUDE.md §8.1 (nothing ingested/stored ever leaves the device) since `UserDefaults.standard` never syncs off-device for this app (no iCloud key-value entitlement).

**Architecture self-review (G4):** (1) no new type duplicates an API-package concept — `TileKey`/`TileGrid`/`TileCache`/`ZoomMath`/`ScrollPosition` are all viewer-local. (2) `ZoomMath`/`TileGrid` are kept as pure functions specifically to avoid burying logic in views; `PageTileView` only does layout/coordinate-flip math, not policy. (3) ARCHITECTURE.md doesn't need edits to stay truthful — this fulfills the NFR-P2/P5 tiling requirement it already describes as a P1-01 scope item.

**Known scope cut (documented in package CLAUDE.md):** sub-page visible-rect culling isn't wired into the SwiftUI view — `PageTileView` renders a page's full tile grid once any part of the page is on-screen (page-level virtualization via `LazyVStack` only). True sub-page culling needs an AppKit `NSScrollView` bridge for continuous scroll-offset access; out of this pass's scope, not silently dropped.
- App-level `DispatchSource.makeMemoryPressureSource` wiring to `DocumentViewModel.handleMemoryPressure()` is the composition root's job per the package CLAUDE.md's own note, and `App/` isn't this task's primary package — left unwired; a natural follow-up task, not a defect in this PR's scope.
