# P1-06 — Page Management Operations

**Epic:** E5 · **Primary package:** `Packages/DocEngineHost` (page ops) + `DocumentSession` (thumbnail interactions) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Reorder (drag in thumbnails), rotate, insert (blank/from file), delete, duplicate, extract, split, and merge PDFs — all undoable, all corruption-safe.

## Background
PRD FR-1.5. Implements `PageOrganizer` from PDFEngineAPI; UI rides the P1-02 thumbnail selection model. Save-path integrity depends on P1-16 (atomic save) — page ops must go through it.

**P1-02 handoff (read before designing drag-reorder):** the selection model is `Packages/DocumentSession/Sources/DocumentSession/Sidebar/ThumbnailSelectionModel.swift` — selection identity is *positional* (`PageIndex`), documented on the type. After any reorder/insert/delete you must remap or `clear()` the selection; if selection needs to survive reorder visually, introduce a stable per-page identity at the engine seam (that's a frozen-seam/ADR change — budget for it). Sidebar click/⌘/⇧ dispatch happens in `ThumbnailSidebarView.handleTap`; navigation uses `DocumentViewModel.navigate(to:)`.

## Requirements
- Engine: page-tree manipulation incl. cross-document page import (fonts/resources carried correctly); merge/split as document-level ops.
- UI: drag-reorder with drop indicators, multi-select ops, context menus, toolbar; insert-from-file flow.
- Every operation on the DocumentSession undo stack.

## Dependencies
- P1-02, P1-16.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/DocEngineHost/` (PDFiumEngine + a `PageOrganizer` conformance; add `fpdf_ppo.h`/page-tree headers to `CPDFium` incrementally); `Packages/DocumentSession/Sources/DocumentSession/Sidebar/`.

## Acceptance Criteria
- Round-trip suite: any sequence of 50 random page ops → save → reopen → structure matches expectation, zero corruption on corpus sample.
- Merged output opens correctly in Acrobat/Preview with annotations and forms intact.

## Definition of Done
- Global DoD, plus: page-ops fuzz sequence added to corpus-roundtrip suite.

## Testing Requirements
- Property-based op-sequence tests; resource-preservation tests (fonts, links) on merge/extract.

## Documentation Updates
- None beyond package CLAUDE.md files.
