# Fixtures

Data-driven test corpus for Vaultform (root CLAUDE.md SS6, docs/REPO_STRUCTURE.md principle 8):
regression cases are fixture + manifest additions, not bespoke test scaffolding.

**Absolute rule (Constitution Art. 15): synthetic data only.** No real personal
data ever enters this directory. `Scripts/scan-fixtures-pii.sh` runs on every
PR and scans for SSN/credit-card/AWS-key/private-key-shaped patterns.

## Layout

- `pdf-corpus/` — real, freely-licensed PDF files (government forms) +
  a small deliberately-malformed set, for the rendering/round-trip suite.
  See `pdf-corpus/README.md`.
- `forms/` — a subset of the same forms with field-name -> vault-path
  mappings for the autofill matcher/fill-planner benches. See `forms/README.md`.
- `documents/` — synthetic (generated, not downloaded) passport/license/resume
  **data** records for ingestion-extractor testing. See `documents/README.md`.

## Current size vs. target (honest status)

The task that seeded this corpus (P0-08) targets >=500 real-world PDFs and
>=25 of the top-100 government/medical forms. What's actually here today is
a 5-file real starter set (all 5 IRS/USCIS forms, freely downloadable, no
licensing issue) plus a 5-file malformed set derived from it. Bulk corpus
acquisition is flagged in `docs/ROADMAP.md` SS4 as "the main human-in-the-loop
dependency" this project has — it is not something an agent is expected to
self-serve at scale. The gap, and the plan to close it, are tracked in:

- `tasks/escalations/E-005-corpus-acquisition-gap.md`
- `docs/specs/corpus-plan.md`

## Licensing notes

- The 5 `pdf-corpus`/`forms` PDFs are IRS/USCIS forms: US federal government
  works, public domain, fetched directly over HTTPS from `irs.gov`/`uscis.gov`.
  No licensing restriction on redistribution. `source_url` and `license_note`
  are recorded per row in each `manifest.json`.
- `documents/` contains no downloaded material at all — every record is
  generated locally by `documents/generate.swift`.

## Adding a regression case

Add the fixture (or a generator seed/count change) plus the corresponding
manifest row in the same PR — see each subdirectory's `README.md` and
`Scripts/bench.sh` for how each manifest is validated.
