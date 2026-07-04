# P0-08 — Fixtures Corpus & Benchmark Harness

**Owner:** agent · **Branch:** task/P0-08-fixtures-bench-harness · **Claimed:** 094af941faf17b356fb2474729a4b0e0a1a8f668

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

## Journal

### Context read
Root `CLAUDE.md` (full), `docs/AGENT_LOOP.md` (full, esp. Step 8a merge
policy), this task file, `docs/ROADMAP.md` SS4 (corpus acquisition as the
human-in-the-loop dependency), `docs/CONSTITUTION.md` Art. 13/14/15,
`tasks/escalations/E-003.md` and `E-004.md` (as templates and for the
current PDFium-build-blocked state), `Scripts/scan-fixtures-pii.sh`,
`Scripts/codegen.sh`, `Scripts/check-boundaries.sh`, `Scripts/verify.sh`
(existing shell conventions), `.github/workflows/ci.yml` and the `bench.yml`
stub, `docs/REPO_STRUCTURE.md` (Fixtures/Scripts layout), `Schemas/vault-schema.yml`
(confirmed empty — P0-09 not landed).

### Plan (as executed)
1. Fetch a small *real* starter corpus (govt forms, HTTPS, no license issue)
   instead of the full 500/25 targets — per explicit scoping guidance, since
   bulk acquisition is the project's own named human-in-the-loop dependency.
2. Build `Fixtures/pdf-corpus/manifest.json` (rows + malformed_rows) using
   Apple PDFKit as a one-time authoring-time inspection tool (not PDFium,
   not shipped) for page_count/text_sha256; file_sha256 needs no PDF engine.
3. Build `Fixtures/forms/manifest.json` with field_name -> vault_path
   mappings verified against the real PDF field names + rendered page
   images (not guessed), noting vault_path is provisional pending P0-09.
4. Write `Fixtures/documents/generate.swift`: seeded deterministic generator,
   full ICAO 9303 MRZ (TD3 + TD1) with correct check digits, independently
   verified against an out-of-band Python re-implementation of the algorithm.
5. Write `Scripts/bench.sh` with 5 suites (corpus-open, manifest-validate,
   field-mapping, generator-determinism, render-latency), `--all`, and a
   `--self-test` proving each checker has teeth (matches repo convention in
   `scan-fixtures-pii.sh`/`check-boundaries.sh`).
6. File the acquisition-gap escalation (E-005) and `docs/specs/corpus-plan.md`
   instead of silently declaring the >=500/>=25 acceptance criteria met.

### Acceptance Criteria status
- **"`bench.sh corpus-open` runs against P0-06 build and reports pass/fail
  per manifest row"** — PARTIALLY MET, honestly scoped. P0-06 doesn't exist
  yet (blocked by E-004), so there is no engine to run "against." `bench.sh
  corpus-open` runs today and reports genuine pass/fail per manifest row for
  what's checkable without an engine: file presence + `file_sha256`
  integrity (5 real rows + 5 malformed rows, all passing). It explicitly
  lists `engine_open`/`page_count`/`text_sha256`/`render_checksum` as
  skipped, with the reason, in its own JSON output — not faked green.
- **"Synthetic document generator produces visually plausible
  passports/licenses with valid MRZ check digits"** — PARTIALLY MET, honestly
  scoped. "Valid MRZ check digits": MET and verified (ICAO 9303 TD3/TD1,
  independently cross-checked against a Python re-implementation — see
  `Fixtures/documents/README.md`). "Visually plausible": NOT MET — no
  PDFium/rasterizer exists in this repo (E-004), so there is no way to
  produce a visual artifact at all; the generator produces the underlying
  structured data instead, which is documented as a deliberate limitation,
  not silently dropped.

### Definition of Done status
- `docs/specs/corpus-plan.md` filed: DONE (growth plan to 10K/100, references E-005).
- Global DoD: no `Packages/*` touched, no `CLAUDE.md`/`Schemas/`/API edits;
  `Scripts/scan-fixtures-pii.sh` clean; `Scripts/codegen.sh --check` and
  `Scripts/check-boundaries.sh --all` unaffected and still green;
  `Scripts/bench.sh --self-test` passes (3/3 self-tests); SwiftLint clean on
  `Fixtures/documents/generate.swift` (0 errors, 1 non-blocking file_length
  warning at 468 lines vs. the 400-line soft cap — CLAUDE.md SS4 calls the
  cap "soft" and this is fixture tooling, not a Package; kept single-file
  since it's invoked as `swift generate.swift`, matching its documented
  usage everywhere).
- **>=500 real PDFs / >=25 top-100 forms: NOT MET.** Escalated as E-005, not
  silently declared done. 5 real, freely-licensed forms landed instead
  (IRS W-9/W-4/1040/4506-T, USCIS I-9), each independently verified (real
  field names, verified field->vault-path mappings, hash-integrity-checked).

### Security/privacy self-audit
No vault values, no real PII, no real personal data of any kind touched.
Synthetic generator uses ICAO's own reserved fictitious country code
("UTO"), IANA-reserved example domains (RFC 2606), and NANP-reserved
fictional phone numbers (555-01xx) specifically so the synthetic nature is
unambiguous, not just technically true. `Scripts/scan-fixtures-pii.sh` was
run and is clean. No network calls added to any product code path (the
`curl` fetches were an authoring-time, one-time step to populate fixture
files already committed to the repo — not a runtime dependency of anything
in `Packages/`, `Scripts/`, or CI).

### Failure modes
- Malformed PDF fixtures (`Fixtures/pdf-corpus/malformed/`): each is
  confirmed to fail to open via PDFKit at authoring time (see manifest's
  `verified_rejected_by`) — exercises the "never crash, never corrupt"
  product truth once P0-06 exists to consume them.
- `Scripts/bench.sh` on a missing/corrupt manifest: `manifest-validate`
  reports `ok:false` with the specific missing field per row, doesn't crash
  (tested via `--self-test`).
- `generate.swift` with a bad `--kind`: prints a usage error to stderr and
  exits 2, doesn't produce garbled output.
