# P1-05 — Annotations: Notes, Free Text, Ink, Shapes, Stamps

**Epic:** E4 · **Primary package:** `Packages/DocEngineHost` + `DocumentSession` `[INTEGRATION]` · **Complexity:** L · **Priority:** High

## Goal
Complete the PRD FR-1.3 annotation set: sticky notes (with popup), free text boxes, freehand ink, lines/arrows/rectangles/ellipses, stamps, and link annotations (view + create).

## Background
Builds on P1-04's annotation store plumbing; these types are geometry-drawn rather than text-anchored. Coordinate with P1-04 owner on shared annotation-store files — serialize these two tasks or split store vs tools cleanly.

## Requirements
- Engine CRUD for each subtype with spec-compliant appearance streams (so other viewers render them).
- Tool palette UX: tool selection, drawing interactions, property inspector (color, width, opacity, font for free text); move/resize/delete.
- Note popups and comment list sidebar (author, date, reply-free v1).

## Dependencies
- P1-04.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Annotations/**`; `Packages/DocumentSession/Sources/Annotate/**`.

## Acceptance Criteria
- Every subtype round-trips with Acrobat/Preview (renders, selectable, editable).
- Ink drawing latency imperceptible (<8ms point-to-screen) on trackpad.

## Definition of Done
- Global DoD, plus: M1 annotation demo checklist in docs/specs/m1-demo.md.

## Testing Requirements
- Per-subtype serialization + snapshot tests; appearance-stream validation against corpus interop fixtures.

## Documentation Updates
- None beyond package CLAUDE.md files.
