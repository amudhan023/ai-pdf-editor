# P2-06 — Autofill Review Panel UI

**Epic:** E13 · **Primary package:** `Packages/AutofillSession` (views) · **Complexity:** L · **Priority:** Critical

## Goal
The review-before-commit sidebar (PRD FR-4.4): per-field proposed value, confidence badge, vault-source line, accept/edit/reject controls, accept-all-high-confidence, needs-input section, in-document proposal badges synced to panel.

## Background
This is the trust-defining UI of the product. AI proposes, the human disposes — the panel must make review fast enough that users don't resent it (counter-metric in PRD §11).

## Requirements
- Sidebar list grouped by page/section; row: field label, proposed value (editable inline), confidence chip, source ("Passport → passport.number"); click row → scroll document to field, badge highlight.
- Bulk actions: accept-all-high, reject-all; keyboard-first review (arrow/enter/e/r bindings).
- Needs-input list with quick-add-to-vault affordance (FR-4.7) — writes go through IngestionSession-style confirm, not silently.
- Uncommitted proposals visually distinct in-document (badged overlay); panel dismissal = full rollback.
- Explainability popover ("why this value") from proposal provenance (FR-4.10, data already in FieldProposal).

## Dependencies
- P2-05, P2-02 (widget layer for badges/writes).

## Files Likely Affected
- `Packages/AutofillSession/Sources/Review/**`.

## Acceptance Criteria
- Usability script: review a 40-field fill in < 90 seconds keyboard-only.
- No path exists to commit without the panel (code-review checkbox + UI test).

## Definition of Done
- Global DoD.

## Testing Requirements
- View-model tests for all row states; XCUITest accept/edit/reject flows; snapshot tests light/dark.

## Documentation Updates
- None beyond package CLAUDE.md.
