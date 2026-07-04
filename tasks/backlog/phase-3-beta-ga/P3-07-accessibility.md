# P3-07 — Accessibility Pass: VoiceOver-Complete Reading & Filling

**Epic:** E3/E13 · **Primary package:** cross-cutting `[INTEGRATION]` (audit + fixes across UI packages) · **Complexity:** L · **Priority:** High

## Goal
NFR-U2/FR-6.2: full VoiceOver support for reading PDFs and completing the entire fill workflow (manual + autofill review), plus keyboard-completeness, contrast, and Dynamic Type where applicable.

## Background
Accessibility hooks were required in earlier UI tasks (P2-02, P2-06); this is the systematic audit-and-fix pass plus PDF *content* accessibility (reading order from text geometry, tagged-PDF structure where present).

## Requirements
- Document reading: page content exposed via accessibility elements in reading order; navigation by page/heading where structure exists.
- Fill flows: every review-panel action, form widget, and vault editor operable via VoiceOver with meaningful labels/values/hints; focus management through the state machines.
- Keyboard completeness audit: every mouse-only interaction gets a keyboard path.
- Contrast/appearance: light/dark/high-contrast audits; reduced-motion honored.
- Serialize with owners of touched packages; fixes land as small PRs per package under this task's umbrella.

## Dependencies
- P2-06, P2-11, P1-11 (the flows must exist to audit).

## Files Likely Affected
- Small diffs across `Packages/{DocumentSession,AutofillSession,IngestionSession,VaultManagerUI,PrivacyDashboard}` + `App/`.

## Acceptance Criteria
- Scripted VoiceOver run: open form → autofill → review → commit → export, completed eyes-free by a tester unfamiliar with the code.
- Accessibility Inspector audit: zero critical issues across main windows.

## Definition of Done
- Global DoD, plus: accessibility conformance report for GA marketing/App Store notes.

## Testing Requirements
- Automated accessibility audits in XCUITests per window; focus-order regression tests.

## Documentation Updates
- docs/specs/accessibility-report.md.
