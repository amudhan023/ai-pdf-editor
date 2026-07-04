# P3-02 — Flat-Form Fill: End-to-End Integration & Beta UX

**Epic:** E12/E13 · **Primary package:** `Packages/AutofillSession` `[INTEGRATION]` · **Complexity:** M · **Priority:** Critical

## Goal
Wire the visual path into the full autofill experience: inferred fields flow through planner → review panel with beta labeling, position-adjustable placements, and flatten-on-export defaults for scanned forms.

## Background
PRD FR-4.1/M5. Inferred fills are annotations, not widget values — users need nudge/resize affordances for imperfect detection, and the review panel must set expectations (beta badge, lower default confidence ceiling).

## Requirements
- Review panel: "detected fields (beta)" section treatment; per-proposal position preview; nudge/resize handles on placed values before commit.
- Confidence policy: visual-path proposals capped below auto-accept threshold (PolicyKit rule addition — decision table update).
- Missed-field fallback: click-anywhere "add field here" → manual entry or vault pick, feeding FormKnowledge memory for next time.
- Export default for inferred fills = flatten (with explanation).

## Dependencies
- P3-01, P2-06, P2-12.

## Files Likely Affected
- `Packages/AutofillSession/Sources/{Review,VisualFill}/**`; PolicyKit decision-table addition.

## Acceptance Criteria
- M5 script: scanned government-form fixture filled end-to-end, misdetections correctable in ≤2 interactions each.
- No visual-path proposal is ever bulk-accepted above the cap (test).

## Definition of Done
- Global DoD, plus: decision-table doc updated.

## Testing Requirements
- End-to-end UI tests on flat fixtures; cap-enforcement tests; FormKnowledge learning round-trip (correction improves second pass).

## Documentation Updates
- docs/specs/policy-decision-table.md; M5 demo script.
