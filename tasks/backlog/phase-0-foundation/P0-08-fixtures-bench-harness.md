# P0-08 — Fixtures Corpus & Benchmark Harness

**Epic:** E15 · **Primary package:** `Fixtures/` + `Scripts/bench.sh` · **Complexity:** L · **Priority:** High

## Goal
Seed the fixture corpora (PDF rendering corpus, top-forms set, synthetic identity documents) with manifest-driven expectations, plus the harness that runs accuracy/perf suites in CI.

## Background
ROADMAP.md §4: quality is on the critical path even when code isn't — NFR-A1–A4 and the R1/R2 evidence base need this from Wave 0. REPO_STRUCTURE.md principle 8: regression = data change.

## Requirements
- `Fixtures/pdf-corpus/` v1: ≥500 varied real-world PDFs (licenses permitting) + malformed set + `manifest.json` (expected page counts, text hashes, render checksums).
- `Fixtures/forms/` v1: ≥25 of the top-100 target forms (IRS, USCIS, SF-86-class, medical intake) + expected-field manifests (field names → canonical vault paths).
- `Fixtures/documents/`: synthetic passport/license/resume generators (NO real PII; CI scan from P0-02 enforces).
- `Scripts/bench.sh <suite>`: runs perf (render latency) and accuracy (field mapping vs manifests) suites, emits JSON results; `bench.yml` publishes trend artifacts.

## Dependencies
- P0-01, P0-02 (PII scan).

## Files Likely Affected
- `Fixtures/**` (LFS), `Scripts/bench.sh`, `.github/workflows/bench.yml`.

## Acceptance Criteria
- `bench.sh corpus-open` runs against P0-06 build and reports pass/fail per manifest row.
- Synthetic document generator produces visually plausible passports/licenses with valid MRZ check digits.

## Definition of Done
- Global DoD, plus: corpus growth plan (to 10K docs / 100 forms) filed as docs/specs/corpus-plan.md.

## Testing Requirements
- Manifest schema validation test; generator determinism test (seeded).

## Documentation Updates
- `Fixtures/README.md` (adding a regression case, licensing notes).
