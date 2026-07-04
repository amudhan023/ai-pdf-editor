# pdf-corpus — populated by P0-08. NO REAL PII (Constitution Art. 15).

Rendering/round-trip suite. `manifest.json` is the source of truth: `rows`
(valid documents) and `malformed_rows` (deliberately corrupted, must be
rejected safely — CLAUDE.md product truth #5, "never corrupt a user's
document").

## What's here (v1 starter set, not the full target)

- `starter/` — 5 real, freely-licensed IRS/USCIS PDF forms (W-9, W-4, 1040,
  4506-T, I-9), fetched directly over HTTPS. US federal government works are
  public domain; `source_url` + `license_note` are recorded per manifest row.
- `malformed/` — 5 fixtures derived from the same forms by truncation/byte
  corruption (empty file, header-only, mid-stream truncation, garbage body,
  destroyed trailer/xref). Each is confirmed to fail to open (see
  `manifest.json`'s `verified_rejected_by`).

The task's original acceptance criterion was >=500 varied real-world PDFs.
This is 5. `docs/ROADMAP.md` SS4 names bulk corpus acquisition as the one
activity in this project agents can't fully self-serve (government forms are
license-trivial to fetch one at a time; the *volume* and *variety* target —
500+ documents across many producers/PDF versions/languages — needs deliberate
collection effort). See `tasks/escalations/E-005-corpus-acquisition-gap.md`
and `docs/specs/corpus-plan.md` for the gap and the growth plan.

## How `page_count` / `text_sha256` were computed

Using Apple **PDFKit** (a macOS system framework) as a one-time,
authoring-time inspection tool — opening each file, reading `PDFDocument
.pageCount` and each page's `.string`. **This is not PDFium and is not part
of DocEngineHost or the shipping app** — it's the equivalent of opening the
file in Preview.app to record its facts, formalized as a script for
reproducibility, and it never runs as part of the product or `verify.sh`.
`render_checksum` is intentionally *not* recorded: no rasterization engine
(PDFium/`DocEngine.xpc`) exists in this repo yet (P0-06 is blocked, see
`tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`), so
there is nothing to honestly compute it against.

## `Scripts/bench.sh corpus-open`

Runs today, but only checks what's checkable without a PDF engine: every
manifest row's file exists and its `file_sha256` matches (corruption/tampering
detection). It does **not** yet open documents through the real engine or
validate `page_count`/`text_sha256` against a live parse — that half of the
suite is a stub pending P0-06 (see the script's own output for the exact
skip reason). This is deliberate, not a masked failure: see
`docs/specs/corpus-plan.md`.
