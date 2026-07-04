# P3-08 — Onboarding & First-Run Experience

**Epic:** E16 · **Primary package:** `App/` (onboarding flow) · **Complexity:** M · **Priority:** High

## Goal
First-run flow that gets a novice from install → vault created → first successful autofill in ≤10 minutes (NFR-U1, PRD activation funnel).

## Background
Activation is the business: install→profile ≥40%, profile→fill ≥60% (PRD §11). The privacy story must be *shown* (local-only, lock ceremony) not just told; consent moments (update check, opt-in telemetry) live here.

## Requirements
- Welcome sequence: 3-screen value/privacy framing → vault creation ceremony (Touch ID setup, recovery-code one-time display with confirmation) → "add your first document" ingestion prompt with sample-form fallback.
- Guided first fill: bundled sample form (or user's own) with coach marks over the review panel.
- Consent moments: update-check (direct build) and telemetry opt-in — both default off, plainly worded.
- Skippable at every step; re-enterable from Help menu; default-PDF-app prompt at a tasteful moment (after first success, not first launch).

## Dependencies
- P1-11, P2-11, P2-06, P3-05 (tier awareness).

## Files Likely Affected
- `App/Sources/Onboarding/**`.

## Acceptance Criteria
- Usability test (5 novices): median ≤10 min to first accepted autofill; zero participants confused about where data is stored (exit question).
- Skipping everything leaves a fully functional app.

## Definition of Done
- Global DoD, plus: funnel instrumentation events (content-free) wired for P3-09.

## Testing Requirements
- XCUITest full flow + skip paths; recovery-code ceremony test (can't proceed without confirm).

## Documentation Updates
- None beyond App CLAUDE.md.
