# P3-10 — GA Hardening: Acceptance Gates, Perf & Corpus at Scale

**Epic:** E15 · **Primary package:** cross-cutting `[INTEGRATION]` (fix-driven) · **Complexity:** L · **Priority:** Critical

## Goal
Drive the four PRD §8 acceptance gates to green at scale: 10K-document round-trip suite, full benchmark bars (NFR-A1/A3, A2-or-beta), NFR-P1–P5 performance targets on baseline hardware, and the beta-cohort readiness checklist.

## Background
The corpus grows from ~500 to 10K docs (P0-08 plan); this task runs the suites, triages, and lands fixes (or files scoped tasks) until gates pass. Explicitly a burn-down task with a fixed exit, not a feature.

## Requirements
- Corpus expansion to 10K (acquisition per corpus-plan) + forms set to 100; manifests completed.
- Run all gates on M1/16GB baseline + Intel spot-checks; profile and fix top perf regressions (open time, scroll, autofill p50, memory ceiling).
- Fuzz campaign on DocEngine (malformed corpus + mutation fuzzing) — zero app-visible crashes; service crash-recovery verified at scale.
- Beta readiness: crash-free rate instrumentation, feedback channel in-app, known-issues list.
- Gate report: single document with pass/fail evidence per PRD gate for the GA go/no-go.

## Dependencies
- Effectively all Phase 2 + P3-01..P3-06 (final integration); schedule as the last two sprints with feature freeze.

## Files Likely Affected
- Fixes across packages (each as its own small PR); `Fixtures/**`; bench configs.

## Acceptance Criteria
- All four PRD §8 gates green with linked evidence; NFR-P1–P5 measured and met on baseline hardware.
- Zero corruption across 10K round-trip; zero Sev-1s open.

## Definition of Done
- Global DoD, plus: GA gate report docs/specs/ga-gate-report.md signed off.

## Testing Requirements
- This task *is* testing; new regressions become manifest rows before fixes merge.

## Documentation Updates
- GA gate report; known-issues list; corpus-plan closeout.
