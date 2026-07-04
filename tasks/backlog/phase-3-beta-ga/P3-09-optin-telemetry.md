# P3-09 — Opt-In, Content-Free Telemetry

**Epic:** E16 · **Primary package:** `Packages/Platform` (telemetry) · **Complexity:** M · **Priority:** Medium

## Goal
The PRD §11 measurement layer: opt-in (default OFF), aggregate-count-only telemetry (activation funnel, fills per month, acceptance rates) with a payload format that *cannot* carry content, plus crash reporting (opt-in, scrubbed).

## Background
FR-5.3 disqualifies any SDK that can touch content. Build a thin client: named counters/histograms only, enum'd event catalog, no free-form strings, no IDs beyond a random install UUID (rotatable). Endpoint is the third enumerated network connection — dashboard-visible and toggleable.

## Requirements
- Event catalog as a closed enum (compile-time exhaustive); payload schema forbids strings except catalog names; local batching, daily send, silent no-op when off.
- Metrics from PRD §11 wired: funnel events (from P3-08), autofill acceptance/rejection tallies (from AutofillSession events — counts only), ingestion acceptance tallies.
- Crash reporting: MetricKit-based, symbolicated locally, user-previewable before send, scrubber test-verified (no paths/values).
- Privacy Dashboard integration: telemetry toggle, last-sent, payload preview ("see exactly what we send").

## Dependencies
- P3-03, P3-08.

## Files Likely Affected
- `Packages/Platform/Sources/Telemetry/**`; event emission points in session packages (counts only, tiny diffs).

## Acceptance Criteria
- Static guarantee test: payload type cannot encode a free-form string (compile-time proof + runtime schema validation).
- Off by default; network audit (P3-04) stays clean with telemetry off; payload preview matches bytes on the wire.

## Definition of Done
- Global DoD, plus: event catalog reviewed against PRD §11 metric definitions.

## Testing Requirements
- Payload schema tests; batching/off-state tests; crash-scrub verification with planted sensitive strings.

## Documentation Updates
- docs/specs/telemetry-catalog.md; Privacy Dashboard copy.
