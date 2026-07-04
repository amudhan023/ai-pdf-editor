# P2-05 — FillPlanner & AutofillSession State Machine

**Epic:** E12 · **Primary package:** `Packages/AutofillEngine` (planner) + `Packages/AutofillSession` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
Orchestrate the end-to-end fill: field discovery → matching → PolicyKit grants → vault reads → formatting → `FillPlan` (per-field proposals with confidence/provenance) → commit accepted proposals through the engine.

## Background
ARCHITECTURE.md §5.2 sequence. AutofillSession is the workflow state machine (analyzing → proposing → reviewing → committing → done/cancelled) driving the review panel (P2-06). Nothing writes to the document except accepted proposals committed here.

## Requirements
- `FillPlan`/`FieldProposal` types: value rendering, confidence, vault provenance, transform record, sensitivity flag, unmatched-fields list (FR-4.7).
- Grant flow: batch PolicyKit ticket request for matched paths; sensitive paths split for individual confirmation (gating UX in P2-07).
- Profile selection input (person/org) incl. per-field override hooks (FR-4.5).
- Commit: accepted proposals → FormModel writes in one undoable group; `FillCommitted` event (AuditLog + FormKnowledge learning hook).
- Cancellation-safe at every state; crash mid-review loses nothing (document untouched until commit).

## Dependencies
- P2-03, P2-04, P1-10, P0-10.

## Files Likely Affected
- `Packages/AutofillEngine/Sources/Planning/**`; `Packages/AutofillSession/Sources/**`.

## Acceptance Criteria
- End-to-end on W-9 fixture with FakeVaultClient values: correct plan, commit writes only accepted fields, undo reverts the whole fill (M3 core).
- NFR-P3 groundwork: plan generation < 3s on 6-page AcroForm fixture.

## Definition of Done
- Global DoD, plus: M3 demo script docs/specs/m3-demo.md.

## Testing Requirements
- State-machine transition tests; commit atomicity/undo tests; grant-denial and vault-locked paths; perf bench.

## Documentation Updates
- `AutofillSession/CLAUDE.md` state diagram.
