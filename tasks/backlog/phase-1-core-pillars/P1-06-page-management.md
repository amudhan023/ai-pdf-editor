# P1-06 — Page Management Operations

**Epic:** E5 · **Primary package:** `Packages/DocEngineHost` (page ops) + `DocumentSession` (thumbnail interactions) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Reorder (drag in thumbnails), rotate, insert (blank/from file), delete, duplicate, extract, split, and merge PDFs — all undoable, all corruption-safe.

## Background
PRD FR-1.5. Implements `PageOrganizer` from PDFEngineAPI; UI rides the P1-02 thumbnail selection model. Save-path integrity depends on P1-16 (atomic save) — page ops must go through it.

## Requirements
- Engine: page-tree manipulation incl. cross-document page import (fonts/resources carried correctly); merge/split as document-level ops.
- UI: drag-reorder with drop indicators, multi-select ops, context menus, toolbar; insert-from-file flow.
- Every operation on the DocumentSession undo stack.

## Dependencies
- P1-02, P1-16.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Pages/**`; `Packages/DocumentSession/Sources/Sidebar/**`.

## Acceptance Criteria
- Round-trip suite: any sequence of 50 random page ops → save → reopen → structure matches expectation, zero corruption on corpus sample.
- Merged output opens correctly in Acrobat/Preview with annotations and forms intact.

## Definition of Done
- Global DoD, plus: page-ops fuzz sequence added to corpus-roundtrip suite.

## Testing Requirements
- Property-based op-sequence tests; resource-preservation tests (fonts, links) on merge/extract.

## Documentation Updates
- None beyond package CLAUDE.md files.
