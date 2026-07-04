# P2-14 — Content Editing: Text Blocks v1 (ADR-001 Gate)

**Epic:** E6 · **Primary package:** `Packages/DocEngineHost` (edit layer) + editing UI in `DocumentSession` `[INTEGRATION]` · **Complexity:** L · **Priority:** High

## Goal
Edit existing text in a PDF: click into a text block, modify with correct font (embedded-font reuse, substitution warnings), line-level reflow within the block, add/delete text blocks — the MVP-constrained scope of PRD FR-1.4.

## Background
The hardest engine work in the project and the **ADR-001 decision gate**: if this misses its checkpoint, the commercial-SDK escape hatch for the editing layer triggers (ROADMAP.md §5). Scope discipline is part of the task: block-level editing, not page reflow.

## Requirements
- Text-object model over PDFium page objects: block detection (grouping runs), font resolution (embedded subset reuse where legal, system-font substitution with visible warning), encoding handling.
- Edit operations: replace/insert/delete text within a block with intra-block line wrapping; new text block tool; delete block.
- UI: click-to-edit caret experience, font/size/color inspector (constrained to resolvable fonts); all edits undoable, saved via P1-16 path.
- Explicit unsupported-case behavior: Type3/damaged-encoding text → read-only with explanation, never garbled writes.

## Dependencies
- P1-03, P1-16.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Edit/**`; `Packages/DocumentSession/Sources/Edit/**`.

## Acceptance Criteria
- Fixture matrix: typo-fix on 50 varied real PDFs → visually correct output (snapshot), valid PDF, correct in Acrobat/Preview.
- Substitution warning appears exactly when font can't be reused; zero silent glyph corruption on the corpus edit suite.

## Definition of Done
- Global DoD, plus: ADR-001 gate memo (ship/fallback recommendation with evidence).

## Testing Requirements
- Font-resolution unit tests; edit round-trip suite in corpus-roundtrip.sh; encoding edge-case fixtures (CID, subset fonts).

## Documentation Updates
- ADR-001 update; `DocEngineHost/CLAUDE.md` edit-layer model.
