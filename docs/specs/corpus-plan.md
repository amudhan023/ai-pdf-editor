# Fixture Corpus Growth Plan

**Owner:** E15 Quality & Benchmarks · **Status:** starter set landed (P0-08), growth not yet scheduled
**Companion:** `Fixtures/README.md`, `Fixtures/pdf-corpus/README.md`, `Fixtures/forms/README.md`,
`tasks/escalations/E-005-corpus-acquisition-gap.md`

## Why this document exists

`docs/ROADMAP.md` SS4 names the benchmark corpus as running "the whole
project" — quality (NFR-A1-A4) can't be assessed retroactively, so it starts
in Phase 0 even though the code it gates lands much later. The same section
also names bulk corpus acquisition as "the main human-in-the-loop dependency"
this project has: government forms are license-trivial to fetch one at a
time, but the *volume and variety* targets below need deliberate collection
effort an agent can't fully self-serve. This document is the honest plan from
today's starting point to those targets.

## Starting point (P0-08, this task)

| Fixture set | Target | Actual today | Gap |
|---|---|---|---|
| `Fixtures/pdf-corpus/` real documents | >=500 varied real-world PDFs | 5 (IRS W-9/W-4/1040/4506-T, USCIS I-9) | 495 |
| `Fixtures/pdf-corpus/malformed/` | unspecified count, "a malformed set" | 5 (truncation/corruption variants derived from the 5 real files) | none stated, but variety (encrypted PDFs, incremental-update corruption, broken object streams, non-PDF-with-.pdf-extension) is thin |
| `Fixtures/forms/` top target forms | >=25 of the top-100 (IRS, USCIS, SF-86-class, medical intake) | 5, all IRS/USCIS | 20+, and zero medical-intake/SF-86-class representation |
| `Fixtures/documents/` synthetic identity records | "visually plausible" passports/licenses/resumes | 10 each (30 total) of structured data records with correct MRZ check digits; NOT rendered/visual (no PDFium yet) | rendering entirely, once P0-06 unblocks |

See `tasks/escalations/E-005-corpus-acquisition-gap.md` for the full acquisition-gap writeup.

## Target sizes (from the task's Definition of Done)

- **10,000 documents** in `pdf-corpus/` for the round-trip/no-corruption suite (`Scripts/corpus-roundtrip.sh`, a later task).
- **100 forms** in `forms/` (the PRD's top-100 target-form benchmark, R2 mitigation).

## Growth phases

### Phase A — unblock the engine, not the corpus (parallel-safe now)
Corpus growth is *useless* to benchmark against until `DocEngineHost`/PDFium
exists (P0-06, blocked by `tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`).
Priority order right now is resolving E-004 (Option A: bigger-disk machine;
Option B: vetted prebuilt PDFium binary + ADR), not growing `pdf-corpus/`
further — a bigger pile of files nobody can open yet doesn't retire risk.

### Phase B — widen the real-forms set to 25+ (next after Phase A, or in parallel by a human)
Fetch more freely-licensed government forms directly over HTTPS, same method
as this task's starter set (`curl` + `source_url`/`license_note` manifest
rows). Concrete next candidates, all US federal/state government works
(public domain), no licensing blocker:
- IRS: W-2, 1099-NEC, 1099-MISC, Schedule C, 8863, 2848
- USCIS: I-130, I-485, I-765, N-400, G-28
- SSA: SS-5
- DS-160-class (State Dept online form — needs a PDF-export path, may not
  exist as a static PDF; verify before counting it)

Each addition is: download -> run the same PDFKit inspection method as this
task (`Fixtures/pdf-corpus/README.md`) -> add a `pdf-corpus` manifest row ->
if it's also a target form, add a `forms` manifest row with verified
field-name -> vault-path mappings (visually confirmed per
`Fixtures/forms/README.md`, not guessed).

### Phase C — the actual human-in-the-loop work
Two categories need collection effort past what a single HTTPS fetch gives:
1. **Medical intake / SF-86-class forms** — not uniformly free-and-public the
   way IRS/USCIS forms are (medical intake forms are often
   institution-specific templates; SF-86 itself is a real, sensitive
   government form whose *filled* instances must never appear here, though
   the *blank* form is public). Needs a human to identify and vet sources.
2. **The 500-1,000+ real-world PDF variety target** — producer/version/
   language diversity (the PRD's stated risk: "real-world PDFs violate the
   spec constantly") can't come from 5 government forms. This needs either
   a licensed corpus (e.g. an existing academic PDF-diversity dataset, subject
   to a license review per CLAUDE.md SS17) or a broader scrape/collection
   effort with its own licensing review per-source. Both require a human
   decision (money, licensing, or a data-sharing agreement) per
   `docs/AGENT_LOOP.md` SS9's escalation table row: "real-world data
   acquisition."

### Phase D — synthetic document rendering (blocked on the same engine gap)
Once PDFium/a rasterizer exists, extend `Fixtures/documents/generate.swift`'s
output into actual rendered PDF/image artifacts (a passport-shaped page
layout, a driver's-license-shaped layout) so OCR/MRZ-extraction benches have
visual fixtures to run against, not just the underlying data. The MRZ/data
generation logic in this task is already correct and reusable; only the
rendering step is missing.

## What ships without waiting for the above

The tooling built in P0-08 (manifest schema, `Scripts/bench.sh` suites,
generator + determinism check) is sized to validate whatever the corpus
grows to — adding fixtures later is a data-only PR (fixture files +
manifest rows), per `docs/REPO_STRUCTURE.md` principle 8 ("regression = data
change"), not a tooling change.
