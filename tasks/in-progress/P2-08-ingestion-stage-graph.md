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

## Handoff

**Status:** Stage-graph runtime, normalizer (minus DOCX/RTF), classifier, and the `ExtractionCandidate` contract are complete, tested, and verified green. Two things are explicitly not done, both flagged rather than silently skipped:

1. **DOCX/RTF normalization** — detected (magic bytes + extension) but throws `.unsupportedFormat`. Needs a coordinator decision: (a) ADR adding AppKit to `IngestionPipeline`'s import allowlist so `NSAttributedString`'s document-reading initializers can be used directly, or (b) a from-scratch Foundation-only DOCX-zip/RTF-token parser (real, bounded scope — DOCX's `word/document.xml` inside the zip is plain-text-extractable with a hand-rolled zip-central-directory reader + `XMLParser` (which *is* Foundation), RTF's control-word format is a simpler grammar than it looks for plain-text-only extraction). I did not make this call unilaterally per CLAUDE.md §3.7.
2. **Classifier accuracy bench** — no bench-suite infrastructure exists yet for this package (checked `Scripts/bench.sh` — same pre-existing gap `AutofillEngine`'s matcher hit in P2-03, not introduced here). `DocumentClassifierTests` covers all 7 `DocumentType` cases plus both degradation paths (low-confidence, endpoint failure) as real golden-set-shaped unit tests against a scriptable `MockInferenceClient`, but the task's own "≥95%/≥90% top-1 on synthetic fixture set, bench-gated" acceptance criterion has no bench harness to plug into.

**What's done:** `IngestionPipelineRunner` (stage graph: cancellable, progress-reporting, per-extractor error isolation via `withTaskGroup`), `Normalizer` (PDF/TXT/JPEG/PNG/HEIC/TIFF), `PNGEncoder` (hand-rolled, tested), `DocumentClassifier` (7-label constrained choice, graceful degradation), `ExtractionCandidate`/`SourceRegion`/`ExtractorAttribution`, `ExtractorStage` protocol for P2-09/P2-10 to implement against, `Packages/IngestionPipeline/CLAUDE.md` stage-authoring guide.

**Exact state:** branch `task/P2-08-ingestion-stage-graph`, all work committed locally in the worktree `/private/tmp/claude-501/-Users-amudhan-Desktop-project-ai-pdf-editor/e3790af4-14a0-460a-b4b4-8066910d910e/scratchpad/ai-pdf-editor-p2-08`, nothing pushed — coordinator handles push/PR. `Scripts/verify.sh IngestionPipeline` OK, 26/26 tests passing.

**Next steps for whoever picks this up:** P2-09/P2-10 (extractors) can start immediately against `ExtractorStage` — they don't need DOCX/RTF support unless their fixtures specifically require it (identity docs/resume forms are plausibly PDF/image-first anyway). The DOCX/RTF decision and the classifier bench-harness gap are both independent follow-ups, not blockers for extractor work.
