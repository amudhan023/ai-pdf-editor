# P1-02 — Viewer: Thumbnail Sidebar & Outline Navigation

**Epic:** E3 · **Primary package:** `Packages/DocumentSession` (sidebar views) · **Complexity:** M · **Priority:** High

**Owner:** claude-agent · **Branch:** task/P1-02-thumbnails-outline · **Claimed:** 822ecb9a7fd02cc0e47260ac22c16b8d1438bc3e

## Goal
Sidebar with page thumbnails (virtualized) and document outline/TOC tree; click-to-navigate; current-page tracking.

## Background
PRD FR-1.2. Thumbnails become the drag-reorder surface in P1-06 — build with that consumer in mind (selection model, item identity).

## Requirements
- Virtualized thumbnail list using low-res engine tiles; multi-select model.
- Outline tree from engine metadata (add outline read to DocEngineHost if missing — coordinate: this may touch `DocEngineHost`, mark PR `[INTEGRATION]` if so).
- Two-way sync: scroll updates sidebar highlight; sidebar click navigates.

## Dependencies
- P1-01.

## Files Likely Affected
- `Packages/DocumentSession/Sources/Sidebar/**`; possibly `Packages/DocEngineHost` (outline read).

## Acceptance Criteria
- 1,000-page fixture: sidebar opens instantly, memory bounded (virtualization verified).
- Outline navigation lands on correct destination incl. nested bookmarks with zoom targets.

## Definition of Done
- Global DoD.

## Testing Requirements
- Unit tests for selection model; snapshot tests; outline parsing tests against corpus manifest expectations.

## Documentation Updates
- None beyond package `CLAUDE.md` if selection model API added.
