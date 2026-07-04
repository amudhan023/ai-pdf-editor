# P1-04 — Annotations: Text Markup Set

**Epic:** E4 · **Primary package:** `Packages/DocEngineHost` (annotation store) + `DocumentSession` (tools) `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Highlight, underline, strikeout, squiggly — selection-driven creation, spec-compliant storage, edit/delete, Acrobat/Preview interoperable.

## Background
PRD FR-1.3 demands standard annotation objects for round-trip interop (NFR-C2). Uses P1-03 text geometry for selection quads.

## Requirements
- Engine: create/read/update/delete text-markup annotations (quad points, color, opacity, author, dates) persisted per PDF spec.
- UI: text selection → markup toolbar; color swatches; click-to-select existing markup; delete.
- Round-trip: annotations created in Acrobat/Preview render and edit correctly, and vice versa.

## Dependencies
- P1-03.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Annotations/**`; `Packages/DocumentSession/Sources/Annotate/**`.

## Acceptance Criteria
- Round-trip fixture suite (files annotated by Acrobat/Preview) passes both directions.
- Undo/redo works through DocumentSession's undo stack.

## Definition of Done
- Global DoD, plus: interop fixtures added to corpus manifest.

## Testing Requirements
- Serialization tests against PDF-spec expectations; snapshot tests for rendering; undo-stack unit tests.

## Documentation Updates
- None beyond package CLAUDE.md files.
