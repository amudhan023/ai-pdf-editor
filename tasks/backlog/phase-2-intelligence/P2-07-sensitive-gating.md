# P2-07 — Sensitive-Field Gating Integration

**Epic:** E14 · **Primary package:** `Packages/AutofillSession` (+ PolicyKit rules already exist) · **Complexity:** S · **Priority:** Critical

## Goal
Wire NFR-A4 end-to-end: Sensitive-tier proposals require individual confirmation (never bulk-accepted), trigger Touch ID re-auth when freshness lapsed, and are blocked entirely on low-confidence matches.

## Background
Rules live in PolicyKit (P0-10) and Vault.xpc enforces tickets (P1-08); this task is the session/UI integration so the enforcement is visible and unbypassable in the real flow.

## Requirements
- Sensitive proposals excluded from accept-all; rendered with distinct treatment + individual confirm control.
- Stale auth → inline re-auth prompt before value is even fetched for display (value absent until grant).
- Low-confidence + sensitive → proposal shown as "needs manual review" with no prefetched value.
- All gating outcomes audited (grant/deny/reauth events).

## Dependencies
- P2-05, P2-06, P1-09.

## Files Likely Affected
- `Packages/AutofillSession/Sources/Review/Sensitive*`; small PolicyKit input additions if needed (coordinate — PolicyKit changes need decision-table update).

## Acceptance Criteria
- Automated test: accept-all on a form containing SSN leaves SSN unfilled pending individual confirm.
- With stale auth, no sensitive value ever reaches the view layer before re-auth (verified by instrumentation test).

## Definition of Done
- Global DoD, plus: decision-table doc updated if rules extended.

## Testing Requirements
- Gating matrix tests (tier × confidence × freshness); UI tests for both prompts.

## Documentation Updates
- docs/specs/policy-decision-table.md.
