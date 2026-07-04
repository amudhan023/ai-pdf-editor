# P0-07 — Minimal Shell App (Open & Display a PDF)

**Epic:** E3 · **Primary package:** `App/` + `Packages/DocumentSession` `[INTEGRATION]` · **Complexity:** M · **Priority:** Critical

## Goal
A launchable app: open a PDF via dialog/drag-drop, display rendered pages in a window — the M0 demo and the substrate all viewer tasks extend.

## Background
Composition root wiring per ARCHITECTURE.md §2.2; `DocumentSession` owns open lifecycle. Deliberately minimal — single window, basic page display, no chrome polish.

## Requirements
- App target with DI composition root; document open via NSOpenPanel + drag-drop + Finder "Open With" (UTType registration).
- `DocumentSession` v1: open → hold engine handle → close; error surface for unopenable files.
- Simple vertically scrolling page view using P0-06 tiles (naive tiling acceptable; real tiling is P1-01).

## Dependencies
- P0-06.

## Files Likely Affected
- `App/**`; `Packages/DocumentSession/Sources/**`.

## Acceptance Criteria
- Open, view, scroll a 100-page PDF; open time < 1s on M1 (NFR-P1 check at M0 scope).
- Corrupt file shows a graceful error, app stays alive.

## Definition of Done
- Global DoD, plus: M0 demo script recorded in docs/specs/m0-demo.md.

## Testing Requirements
- UI smoke test (XCUITest) for open-and-render; DocumentSession unit tests with `FakePDFEngine`.

## Documentation Updates
- `App/CLAUDE.md` composition-root map.
