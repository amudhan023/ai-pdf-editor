# P2-08 — Ingestion Pipeline: Stage Graph, Normalizer & Classifier

**Owner:** claude-agent · **Branch:** task/P2-08-ingestion-stage-graph · **Claimed:** 60b4cb8abb2a614cfe56f31eea81b23df88646c1


**Epic:** E11 · **Primary package:** `Packages/IngestionPipeline` · **Complexity:** L · **Priority:** High

## Goal
The ingestion backbone (ARCHITECTURE.md §5.1): accept PDF/DOCX/images → normalize → OCR-if-needed → classify document type → route to extractors → emit `ExtractionCandidate[]`; plus the document classifier model integration.

## Background
PRD FR-3.1/3.2. Pipeline emits candidates only — persistence happens in the review session (P2-11). Extractors plug in as stages (P2-09/10 are parallel-friendly because of this seam).

## Requirements
- Stage-graph runtime: typed stage protocol, cancellable, progress reporting, per-stage error isolation (bad stage ≠ dead pipeline).
- Normalizer: DOCX/RTF/TXT text extraction, image preprocessing (deskew/contrast via P1-13 pipeline), HEIC handling, PDF page rasterization via engine.
- Classifier endpoint integration (bundled Core ML model via registry): passport | license | resume | filled-form | certificate | utility-bill | generic, with confidence.
- `ExtractionCandidate` type: value, proposed vault path, source region (doc/page/rect), confidence, extractor attribution.

## Dependencies
- P1-12, P1-13.

## Files Likely Affected
- `Packages/IngestionPipeline/Sources/{Graph,Normalize,Classify}/**`.

## Acceptance Criteria
- Classifier ≥90% top-1 on synthetic fixture set (bench-gated); misclassification routes to generic extractor, never a crash.
- Pipeline handles a corrupt DOCX and a 50MB photo gracefully (typed errors, bounded memory).

## Definition of Done
- Global DoD.

## Testing Requirements
- Stage-graph unit tests (cancellation, error isolation); classifier bench; format-matrix ingestion smoke.

## Documentation Updates
- `IngestionPipeline/CLAUDE.md` stage-authoring guide (extractor tasks depend on it).

## Journal

**Orient:** Root CLAUDE.md; `Packages/IngestionPipeline/CLAUDE.md` (empty scaffold — greenfield within the package); `Scripts/import-allowlist.txt` (Foundation/PDFEngineAPI/VaultAPI/InferenceAPI only — critically, no AppKit, unlike `IngestionSession`'s allowlist). Read `InferenceAPI.ClassifyRequest`/`OCRRequest`/`InferenceClient` (frozen contracts), `PDFEngineAPI.PageRenderer`/`TextEditor`/`Geometry` (confirmed this package already hand-rolls `PDFPoint`/`PDFRect` instead of importing CoreGraphics — same constraint this task hits again for PNG encoding), `VaultAPI.FieldPath`. Read `InferenceHost.VisionOCRProvider` to confirm `imageData: Data` must be `ImageIO`-decodable bytes (PNG/JPEG/etc.), and that deskew/contrast preprocessing already happens there (P1-13) — resolves the task wording's "image preprocessing via P1-13 pipeline" as "not this package's job."

**Plan:** Two real import-allowlist boundary gaps found, handled differently:
1. **DOCX/RTF normalization** — `NSAttributedString`'s document-reading initializers for `.officeOpenXML`/`.rtf` are AppKit-only; AppKit isn't in this package's allowlist. No Foundation-only alternative exists (DOCX is a zip+XML container, RTF a bespoke token format — no built-in Foundation support either way). **Escalated, not forced**: implemented format detection (magic bytes: ZIP signature for DOCX, `{\rtf1` for RTF) so the pipeline recognizes these formats and fails with a precise typed `.unsupportedFormat` error rather than silently mis-normalizing or crashing — never implemented normalization itself. Needs a coordinator decision: ADR adding AppKit here, or a from-scratch Foundation-only DOCX-zip/RTF-token parser (real scope, not a quick add).
2. **PDF-page-to-image encoding** — `RenderedTile.pixelData` is raw RGBA8; `ClassifyRequest`/`OCRRequest.imageData` must be `ImageIO`-decodable (confirmed via `VisionOCRProvider`'s `CGImageSourceCreateWithData` call), which needs an image *encoder*, and ImageIO/CoreGraphics aren't in this package's allowlist either. **Resolved without escalating**: hand-rolled a minimal, spec-valid PNG encoder (`Normalize/PNGEncoder.swift`) using uncompressed/"stored" DEFLATE blocks (RFC 1951 §3.2.4) — zero new dependency, Foundation-only, ~140 lines, fully deterministic and testable. Judged this as CLAUDE.md §17's "write it ourselves" being clearly cheaper/safer than an ADR + AppKit import into a non-UI package for something this self-contained, unlike DOCX/RTF where no bounded, well-specified from-scratch alternative exists.

**Implement:** `Graph/` (`ExtractorStage` protocol, `IngestionPipelineRunner` actor: normalize -> classify -> concurrent per-supports()-matching extractors via `withTaskGroup`, per-extractor failure isolation into `IngestionResult.failedExtractors`, cooperative cancellation, sync progress callback), `Normalize/` (`DocumentFormat` magic-byte+extension detection, `Normalizer`, `PNGEncoder`, `NormalizedDocument`/`NormalizedPage`), `Classify/` (`DocumentType` 7-label closed set, `DocumentClassification`, `DocumentClassifier` — low-confidence and endpoint-failure both degrade to `.generic`, never throw), `ExtractionCandidate`/`SourceRegion`/`ExtractorAttribution` (reuses `PDFEngineAPI.PageIndex`/`PDFRect` and `VaultAPI.FieldPath` rather than inventing geometry/path types).

**Verify:** `Scripts/verify.sh IngestionPipeline` — OK. `Scripts/check-boundaries.sh IngestionPipeline` — clean. 26 tests, full Xcode.app, ran for real (`PNGEncoderTests` independently re-parses the stored-deflate/zlib framing and checks CRC32/Adler32 — there's no `ImageIO` available in this package to round-trip-decode against, so the test verifies wire-format correctness directly rather than via a decode-and-compare).

**Harden notes:** `Normalizer.maxInputBytes` (200MB) rejects oversized input by `FileManager` size lookup *before* reading bytes — the 50MB-photo acceptance criterion is comfortably inside this, the cap exists for the pathological/corrupt case. Every `PDFEngineError` crossing into this package is translated to a typed `IngestionError`, never re-thrown raw. Security/privacy self-audit: `debugDescription` on every error case is counts/enum-states/format-identifiers only, no document content (CLAUDE.md §16); no logging added; no network; nothing writes to the vault (this package only emits `ExtractionCandidate`s, matching its documented purpose).

**Update (coordinator decision, ADR-017):** DOCX/RTF normalization is now implemented. Coordinator wrote `docs/adr/ADR-017-ingestionpipeline-compression-framework.md` and added Apple's system `Compression` framework to `IngestionPipeline`'s import allowlist (not AppKit — keeps a UI framework out of a Domain-layer package; system frameworks are already precedented per-package, e.g. `InferenceHost` lists Vision/ImageIO/CoreGraphics). Implemented:
- `DocxTextExtractor.swift`: hand-rolled ZIP local-file-header walker (bounded, every length field checked against the buffer before use, typed `.corruptInput` on truncation/malformed input, never a crash) locates `word/document.xml`'s compressed byte range, inflates it via `compression_decode_buffer` (`COMPRESSION_ZLIB` = raw DEFLATE, matching ZIP method 8; method 0/stored is a straight copy, no decompression), then `Foundation.XMLParser` (already unrestricted) collects `<w:t>` run text. **Scope cut, documented in the file's doc comment**: only local headers with real (non-zero, non-data-descriptor) size fields are supported — real Office/LibreOffice DOCX output always does this; the streamed/data-descriptor zip form is a typed `.corruptInput`, not a crash, if ever encountered.
- `RtfTextExtractor.swift`: hand-rolled Foundation-only control-word tokenizer — groups, control words/symbols, `\'hh` hex escapes (Latin-1), `\par`/`\line` → newline, skips non-text destinations (`\fonttbl`/`\colortbl`/`\stylesheet`/`\info`/`\generator`/etc. and `\*`-marked "ignorable" destinations) rather than emitting their content as text. Unbalanced braces → typed `.corruptInput`, never a crash.
- Wired into `Normalizer.normalize` replacing the `.unsupportedFormat` stub for `.docx`/`.rtf`.
- Tests (`DocxRtfExtractionTests.swift`, 12 new): stored- and DEFLATE-compressed DOCX round trips (`DocxFixtureBuilder.swift` hand-constructs both, using `compression_encode_buffer` for the real-DEFLATE fixture — exercises the actual inflate path, not just the stored/copy path), truncated-DOCX and missing-entry typed-error cases, RTF plain text/font-table-skip/hex-escape/ignorable-destination/unbalanced-brace cases, and Normalizer-level wiring tests including the Acceptance Criteria's "corrupt DOCX handled gracefully" case.
- `Scripts/verify.sh IngestionPipeline` — OK, 36/36 tests. `Scripts/check-boundaries.sh IngestionPipeline` — clean (only new import is `Compression`, per ADR-017).
- Two old `NormalizerTests`/`IngestionPipelineRunnerTests` cases asserting the old "DOCX/RTF unsupported" behavior were updated to assert real extracted-text behavior instead (and to use a genuinely unrecognized/no-magic-bytes fixture for the still-real "`.unsupportedFormat(.unknown)`" case) — behavior legitimately changed, so the test change belongs with this commit, not a separate one.

**Still not done, unchanged from before:** classifier accuracy bench-suite infrastructure — no `Scripts/bench.sh` scaffolding exists yet for this package (same pre-existing gap `AutofillEngine`'s matcher hit in P2-03). `DocumentClassifierTests` covers all 7 `DocumentType` cases plus both degradation paths as real golden-set-shaped unit tests, but the task's own "bench-gated ≥90% top-1" acceptance criterion has no harness to plug into.

**What's done:** `IngestionPipelineRunner` (stage graph), `Normalizer` (PDF/TXT/JPEG/PNG/HEIC/TIFF/DOCX/RTF — full format coverage the task asked for), `PNGEncoder`, `DocxTextExtractor`/`RtfTextExtractor`, `DocumentClassifier`, `ExtractionCandidate`/`SourceRegion`/`ExtractorAttribution`, `ExtractorStage` protocol for P2-09/P2-10, `Packages/IngestionPipeline/CLAUDE.md` stage-authoring guide, `docs/adr/ADR-017-ingestionpipeline-compression-framework.md`.

**Exact state:** branch `task/P2-08-ingestion-stage-graph`, all work committed locally in the worktree `/private/tmp/claude-501/-Users-amudhan-Desktop-project-ai-pdf-editor/e3790af4-14a0-460a-b4b4-8066910d910e/scratchpad/ai-pdf-editor-p2-08`, nothing pushed — coordinator handles push/PR. `Scripts/verify.sh IngestionPipeline` OK, 36/36 tests passing.

**Next steps for whoever picks this up:** P2-09/P2-10 (extractors) can start immediately against `ExtractorStage` — full format coverage is now available including DOCX/RTF. The classifier bench-harness gap is an independent follow-up, not a blocker for extractor work.
