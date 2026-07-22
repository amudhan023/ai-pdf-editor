# ADR-017 — IngestionPipeline: add `Compression` for DOCX normalization

**Status:** Accepted · **Task:** P2-08 · **Date:** 2026-07-22

## Context

P2-08's normalizer stage needs DOCX/RTF text extraction. DOCX is a zip
archive of XML parts; RTF is a plain-text control-word format.

The obvious macOS approach — `NSAttributedString`'s document-reading
initializers for `.officeOpenXML`/`.rtf` — lives in AppKit's category on
`NSAttributedString`, not pure Foundation. `Packages/IngestionPipeline` is a
Domain-layer stage-graph package with no UI; importing AppKit (a UI
framework) into it to reach one initializer would blur that layering for
every future reader of this package's import list, and CLAUDE.md §17's
default answer to "new dependency" is no regardless.

DOCX's zip container uses real DEFLATE compression (not the stored/uncompressed
blocks `PNGEncoder` uses for its own encode-only need) — decoding that without
a library means hand-rolling a full Huffman-based inflate, which is a correctness-
and security-sensitive parser (malformed/adversarial zip input) not worth
reinventing when Apple ships one.

## Decision

Add Apple's system `Compression` framework (`compression_decode_buffer`,
zlib/deflate) to `IngestionPipeline`'s import allowlist, for DOCX zip-entry
decompression only. This is not a third-party dependency (§17 governs
third-party libraries; system frameworks are already precedented per-package
in `Scripts/import-allowlist.txt` — e.g. `InferenceHost` already lists
`Vision`/`ImageIO`/`CoreGraphics`) and it keeps AppKit out of a non-UI
package. `docx.xml`'s text is then walked with `Foundation.XMLParser`
(already unrestricted — pure Foundation), extracting `<w:t>` run text.

RTF gets a hand-rolled, Foundation-only control-word tokenizer (bounded
grammar: `\controlword`, groups `{}`, plain text runs, `\'hh` hex escapes) —
no compression involved, so no allowlist change needed for it.

Both paths are additive to `Packages/IngestionPipeline/Sources/IngestionPipeline/Normalize/`;
no existing normalizer behavior changes.

## Consequences

- `Scripts/import-allowlist.txt`: `IngestionPipeline` gains `Compression`.
- A malformed/truncated DOCX zip must fail as a typed `IngestionError`
  (never a crash) — `compression_decode_buffer`'s bounded-output-buffer API
  makes this straightforward to enforce (unlike an unbounded custom inflate).
- Self-mergeable once this ADR is present and CI is green, per ADR-008.
