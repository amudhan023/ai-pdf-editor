# P1-01 — Viewer: Continuous Scroll, Zoom & Real Tiling

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
