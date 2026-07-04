# documents — populated by P0-08. NO REAL PII (Constitution Art. 15).

Synthetic passport/license/resume **data** generator for ingestion-extractor
testing (MRZ extraction, resume NER, etc.).

## Rendering limitation (read this first)

`generate.swift` produces structured JSON records — it does **not** produce a
rendered PDF, PNG, or any visual artifact. PDFium is not buildable on this
machine (`tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`);
without a rasterizer there is no way to turn a record into a passport-shaped
image and no honest way to claim otherwise. `synthetic/` holds the data a
future renderer would consume once P0-06 unblocks. Every record's fields are
exactly what a real MRZ/OCR extractor would need to be tested against once
that renderer exists.

## Generating fixtures

```
swift Fixtures/documents/generate.swift --kind passport --count 10 --seed 42 --out Fixtures/documents/synthetic/passports
swift Fixtures/documents/generate.swift --kind license  --count 10 --seed 42 --out Fixtures/documents/synthetic/licenses
swift Fixtures/documents/generate.swift --kind resume   --count 10 --seed 42 --out Fixtures/documents/synthetic/resumes
```

Deterministic: the same `--seed` always produces byte-identical JSON (uses a
seeded SplitMix64 generator, not Foundation's unseedable
`SystemRandomNumberGenerator`; JSON is encoded with `.sortedKeys` so key order
can't vary run to run). `Scripts/bench.sh generator-determinism` checks this
by running the generator twice and diffing output.

## MRZ (machine-readable zone) correctness

Passport (`TD3`, 2 lines x 44 chars) and the ID-card-style `license` (`TD1`,
3 lines x 30 chars) both carry **real, correctly-computed ICAO Doc 9303 check
digits** — weighted mod-10 over cycling weights `[7,3,1]`, char values
`0`-`9`=0-9, `A`-`Z`=10-35, `<`=0 — implemented in `generate.swift`'s `MRZ`
enum. This was independently verified against an out-of-band Python
re-implementation of the same algorithm during authoring (all check digits
and composite check digits matched).

`license` models an ICAO TD1 MRZ-bearing ID-card document (as printed on
national ID cards / some countries' ID-card-format licenses), **not** a
specific US state driver's license — US state DLs encode data in a PDF417
barcode per the AAMVA spec, which has no public, universal check-digit
standard and (like MRZ rendering) needs a barcode/image renderer neither of
which exist here yet. `formatNote` on every license record states this.

Resumes carry no MRZ — there's no standardized machine-readable check-digit
scheme for resumes to be correct *about*.

## No real PII

Names are drawn from an obviously-synthetic word list (e.g. "Fixtureworth",
"Sampleford"); nationality/issuing state is fixed to `UTO`, the
ICAO-reserved fictitious country code ("Utopia") used in the standard's own
specimen documents; emails use the IANA-reserved `example.com`/`.org`/`.net`
domains (RFC 2606); phone numbers use the NANP-reserved `555-01XX` fictional
range. `Scripts/scan-fixtures-pii.sh` runs on every PR regardless.
