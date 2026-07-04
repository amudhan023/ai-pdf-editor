# P2-02 — Manual Form Fill UI

**Epic:** E7 · **Primary package:** `Packages/DocumentSession` (form widgets) · **Complexity:** M · **Priority:** High

## Goal
Interactive manual filling: native-feeling widgets over form fields (text, checkbox, radio, combo, list, date), tab-order keyboard navigation, field highlighting.

## Background
PRD FR-1.8. Manual fill must be excellent independent of AI — it's also the interaction layer the autofill review flow (P2-06) writes through and the VoiceOver fill target (P3-07); build accessibility hooks now.

## Requirements
- Overlay widgets bound to FormModel; correct fonts/sizes; comb-field character boxes; date pickers where format hints say date.
- Tab/shift-tab traversal per tab order; Enter/Space semantics; "highlight fields" toggle.
- Value edits → FormModel writes → undo stack → dirty state.

## Dependencies
- P2-01.

## Files Likely Affected
- `Packages/DocumentSession/Sources/Forms/**`.

## Acceptance Criteria
- Keyboard-only fill of the W-9 fixture end-to-end; screen-reader labels present on every widget kind (VoiceOver smoke).
- Filled output opens correctly in Acrobat/Preview.

## Definition of Done
- Global DoD.

## Testing Requirements
- Widget unit tests per field kind; XCUITest keyboard traversal; accessibility audit smoke.

## Documentation Updates
- None beyond package CLAUDE.md.
