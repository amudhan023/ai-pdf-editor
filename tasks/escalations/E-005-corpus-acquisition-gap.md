# E-005 — Fixture corpus is far below its target size (P0-08 scoped down)

**Raised by:** P0-08 · **Severity:** DoD gap, not a code defect — the tooling (manifests, `Scripts/bench.sh`, generators) is complete and correct against what exists; the *data volume* is the gap.

## Evidence

- P0-08's task file (`tasks/backlog/phase-0-foundation/P0-08-fixtures-bench-harness.md`) requirements state:
  - `Fixtures/pdf-corpus/` v1: >=500 varied real-world PDFs + malformed set + manifest.
  - `Fixtures/forms/` v1: >=25 of the top-100 target forms + expected-field manifests.
- What actually landed in this PR: 5 real PDFs (`irs-fw9.pdf`, `irs-fw4.pdf`, `irs-f1040.pdf`, `irs-f4506t.pdf`, `uscis-i9.pdf`), all fetched directly over HTTPS from `irs.gov`/`uscis.gov` (US federal government works, public domain, `source_url` + `license_note` recorded per manifest row), plus a 5-file malformed set derived from them by truncation/byte corruption.
- `docs/ROADMAP.md` SS4 states this directly: "Benchmark corpus is on the critical path for *quality* though not for *code* ... form acquisition is the one activity agents can't fully self-serve (licensing of government forms is trivial; medical/HR packets need collection effort) — this is the main human-in-the-loop dependency." Government forms were trivial to fetch one at a time (five HTTPS `curl` calls, no licensing review needed beyond noting "US federal government work, public domain"); the *volume and variety* target (500+ documents spanning many producers/PDF versions/languages, plus non-government form categories like medical intake and SF-86-class) is not something this task attempted to bulk-acquire, per the explicit scoping guidance this task was launched with.
- Separately, `Fixtures/pdf-corpus/` real-engine validation (`page_count`/`text_sha256` live re-parse, `render_checksum`) can't run against the actual product engine yet regardless of corpus size: `DocEngineHost`/PDFium isn't buildable on this machine (`tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`, P0-06 blocked). `Scripts/bench.sh corpus-open` only validates file-presence + `sha256` integrity today and says so in its own JSON output (`skipped_checks`).

## Conclusion

This is not a fixable-by-retrying gap for a single agent session: reaching 500+ varied real-world PDFs and 25+ of the top-100 target forms (with several non-government categories in that top-100) needs either (a) a much longer, deliberate multi-source acquisition effort, or (b) a licensed/vetted bulk dataset, both of which are human-in-the-loop decisions per `docs/AGENT_LOOP.md` SS9's escalation table row "real-world data acquisition." Building 100x more manifest tooling doesn't close this gap; the tooling built in this task (manifest schema + `Scripts/bench.sh` suites + generators) is already sized to validate whatever the corpus grows to.

## Decision needed (human)

Option A: approve continued organic growth via Phase B of `docs/specs/corpus-plan.md` (more individual HTTPS fetches of freely-licensed government forms) — closes the `forms/` gap toward 25 over several small follow-up PRs, but does not by itself reach 500 varied documents (still all one narrow category: US government AcroForms) or cover medical-intake/SF-86-class forms.

Option B: identify and approve a licensed/vetted bulk PDF corpus (e.g. an existing academic PDF-diversity dataset) for the 500+ variety target — requires a license review per CLAUDE.md SS17 (license compatibility with commercial distribution, supply-chain posture) since this is *data*, not code, but the same "evidence over assertion" bar applies.

Option C (current default, unblocks other Phase 0 work): proceed with the 5-file starter set as `pdf-corpus`/`forms` v1, tracked here and in `docs/specs/corpus-plan.md`, and revisit corpus size growth as its own scheduled task once P0-06 (PDFium/DocEngineHost) actually exists to validate against — growing the corpus further before there's an engine to open documents with doesn't retire risk.

## Interim decision (made now, so the backlog isn't blocked entirely)

Proceeding with Option C. P0-08's manifest schema, `Scripts/bench.sh` suites, and `Fixtures/documents/generate.swift` are complete and validated against the 5-file starter set; this escalation and `docs/specs/corpus-plan.md` carry the honest gap forward instead of the task silently claiming the >=500/>=25 acceptance criteria were met.

## After repair

Whichever option: update this file's status and `docs/specs/corpus-plan.md`'s "Starting point" table with the new counts once more fixtures land; each addition is a data-only PR (fixture + manifest row), not a tooling change, per `docs/REPO_STRUCTURE.md` principle 8.
