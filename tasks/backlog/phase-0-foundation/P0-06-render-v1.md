# P0-06 — DocEngine.xpc Render Pipeline v1

**Epic:** E2 · **Primary package:** `Packages/DocEngineHost` · **Complexity:** L · **Priority:** Critical

## Goal
Implement `PageRenderer` on PDFium inside DocEngine.xpc: open document from security-scoped handle, page metadata, rasterize page tiles to IOSurface.

## Background
ARCHITECTURE.md §2.3: DocEngine.xpc is per-document, no-entitlement, hostile-input sandbox. This task delivers the first real engine capability behind the P0-04 protocols over the P0-05 transport.

## Requirements
- Open/close documents (incl. password-protected open path); page count/size/rotation; render tile (page, rect, scale) → IOSurface, correct color management.
- Per-document service instance lifecycle managed by `DocEngineHost` client (spawn, reuse, teardown).
- Passes the P0-04 conformance suite for implemented protocols.
- Memory: streamed rendering only; no full-document rasterization (NFR-P5 groundwork).

## Dependencies
- P0-03, P0-04, P0-05.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/**`; `Services/DocEngineService/**`.

## Acceptance Criteria
- Corpus sample (100 varied PDFs incl. malformed set) opens or fails gracefully — zero service-host crashes surfacing to app.
- Tile render p50 < 16ms at 1x for corpus text pages on M1 (NFR-P2 groundwork), measured in bench harness.

## Definition of Done
- Global DoD, plus: malformed-PDF fuzz seed set added to corpus manifest.

## Testing Requirements
- Conformance suite green; render-snapshot tests against reference rasters; crash-isolation test (poison PDF kills service, app recovers).

## Documentation Updates
- `Packages/DocEngineHost/CLAUDE.md` (lifecycle model, IOSurface contract).
