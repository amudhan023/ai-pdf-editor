# IngestionPipeline

**Purpose:** Document ingestion stage graph: normalize -> OCR -> classify -> extract -> map -> conflict-detect. Emits ExtractionCandidates only - never writes to the vault.

**Allowed imports:** Foundation, PDFEngineAPI, VaultAPI, InferenceAPI, `Compression` (system framework, ADR-017 — DOCX zip decompression only) — see `Scripts/import-allowlist.txt` — the enforced source of truth. Tests may also import XCTest.

**Verify:** `Scripts/verify.sh IngestionPipeline` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.

**Stage graph (P2-08):** `IngestionPipelineRunner.run(fileURL:document:onProgress:)` is the fixed sequence `Normalizer.normalize` -> `DocumentClassifier.classify` (both required, no downstream to isolate them from) -> every registered `ExtractorStage` whose `supports(_:)` matches the classification, run **concurrently** via `withTaskGroup` with per-extractor failure isolation: one extractor throwing never discards another's candidates or kills the run (`IngestionResult.failedExtractors`). Cancellation is cooperative (`Task.checkCancellation()` between stages; a cancelled parent `Task` auto-cancels every in-flight extractor).

**Adding an extractor stage (P2-09/P2-10, read before starting):** conform to `ExtractorStage` (`Graph/ExtractorStage.swift`) — `name` for provenance/error-key attribution, `supports(_:)` to opt into the `DocumentType`s you handle, `extract(from:classification:)` returning `[ExtractionCandidate]`. Throw `IngestionError` (or let a real error surface — the runner wraps anything else as `.engine`) rather than returning an empty array on failure, so the caller can tell "found nothing" from "extractor broke." Register the instance in the `extractors:` array passed to `IngestionPipelineRunner.init` at the composition root — no change to this package needed.

**Normalizer scope (P2-08):** PDF (via `PageRenderer` rasterization + optional `TextEditor` text-layer text), TXT, JPEG/PNG/HEIC/TIFF (passthrough — `ImageIO` on the `InferenceHost` side decodes them; deskew/contrast already happens there, P1-13), DOCX (`DocxTextExtractor.swift`: hand-rolled bounded ZIP local-file-header walker + `compression_decode_buffer` inflate + `XMLParser` over `word/document.xml`'s `<w:t>` runs — ADR-017, `Compression` framework not AppKit), RTF (`RtfTextExtractor.swift`: hand-rolled Foundation-only control-word tokenizer, no new import needed). Both throw typed `.corruptInput` on malformed/truncated input, never crash.

**`PNGEncoder`:** hand-rolled RGBA8->PNG (`Normalize/PNGEncoder.swift`) so a `RenderedTile`'s raw pixels can become `InferenceAPI`'s `imageData: Data` without importing ImageIO/CoreGraphics (same "no CoreGraphics" constraint `PDFEngineAPI.Geometry` documents). Uses uncompressed/stored DEFLATE blocks — spec-valid, verified structurally in `PNGEncoderTests` (no ImageIO available here to round-trip-decode against).

**Classifier confidence:** `DocumentClassifier.lowConfidenceThreshold` (0.5) — below it, a real-but-uncertain result degrades to `.generic` the same as an unavailable endpoint. Bench-tunable once a real accuracy bench exists (none does yet for this package — pre-existing gap, same class as `AutofillEngine`'s matcher, see task Journal).
