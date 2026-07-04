# P2-15 — Content Editing: Images

**Epic:** E6 · **Primary package:** `Packages/DocEngineHost` (image ops) + `DocumentSession` (tools) `[INTEGRATION]` · **Complexity:** M · **Priority:** Medium

## Goal
Image operations in existing PDFs (PRD FR-1.4): select, move, resize, replace, delete, insert images; extract image to file.

## Background
Far more tractable than text editing (image XObjects are self-contained). Coordinate with P2-14 on shared edit-layer scaffolding — P2-14 lands the page-object selection model first; this task consumes it.

## Requirements
- Image XObject enumeration/selection with handles; transform (move/resize preserving matrix math incl. rotation); delete with content-stream cleanup.
- Replace/insert: JPEG/PNG/HEIC input, downsampling options, correct color space embedding; alpha handling (SMask).
- Extract image at original resolution to file.
- Undo + P1-16 save path throughout.

## Dependencies
- P2-14 (selection model + edit-layer scaffolding).

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Edit/Images/**`; `Packages/DocumentSession/Sources/Edit/**`.

## Acceptance Criteria
- Replace-logo-on-letterhead fixture: output valid, renders correctly everywhere, file size sane (no orphaned original image data).
- Round-trip edit suite passes with image ops added to the fuzz sequence.

## Definition of Done
- Global DoD.

## Testing Requirements
- Matrix-math property tests; color-space/alpha fixture matrix; orphan-resource cleanup verification.

## Documentation Updates
- None beyond package CLAUDE.md.
