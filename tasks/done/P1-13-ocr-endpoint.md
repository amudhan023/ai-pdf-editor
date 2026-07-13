# P1-13 — OCR Endpoint & Searchable Text Layer

**Owner:** claude-agent · **Branch:** task/P1-13-ocr-endpoint · **Claimed:** 8eb81cd764468ab3acaac6ba8e4785dced1307c8

**Epic:** E10/E2 · **Primary package:** `Packages/InferenceHost` (Vision adapter) + text-layer write in `DocEngineHost` `[INTEGRATION]` · **Complexity:** M · **Priority:** High

## Goal
Real OCR through the Vision adapter (text + geometry + confidence, language auto-detect) and "Make Searchable" — writing an invisible text layer into scanned PDFs.

## Background
PRD FR-1.7 (NFR-A3 accuracy bars); ingestion (P2-08) and flat-form autofill (P3-01) consume the same endpoint. Text-layer write goes through the engine's save path.

## Requirements
- OCR endpoint: page image → text runs with quads, per-run confidence, detected language; batch (background queue) and single-page (interactive) modes.
- Photo-input tolerance: deskew/contrast preprocessing pipeline stage.
- "Make Searchable" document action: OCR all raster pages → invisible text layer → atomic save; progress UI hook via DocumentSession.

## Dependencies
- P1-12; text-layer write also needs P1-16.

## Files Likely Affected
- `Packages/InferenceHost/Sources/Vision/**`; `Packages/DocEngineHost/Sources/TextLayer/**`.

## Acceptance Criteria
- NFR-A3: ≥98% char accuracy on 300-dpi fixture set, ≥93% on phone-photo set (bench suite, CI-gated).
- OCR'd PDF is searchable in-app and in Preview/Acrobat (text layer interop).

## Definition of Done
- Global DoD, plus: OCR accuracy added to bench trend dashboard.

## Testing Requirements
- Accuracy bench vs fixture manifests; geometry alignment tests; 12-language smoke set.

## Documentation Updates
- Fixtures README (OCR ground-truth format).

## Status (2026-07-13)

**Done this iteration:** the real OCR endpoint. `VisionAdapter`/`InferenceHost.VisionOCRProvider` now run `VNRecognizeTextRequest` (`.accurate`, language correction + automatic language detection on) against decoded `imageData`, with a `CIColorControls`-based contrast-normalization preprocessing pass for photo-input tolerance, mapped into the existing `OCRRequest`/`OCRResponse` contract (Vision's bottom-left-origin `boundingBox` converted to `NormalizedRect`'s top-left convention). Undecodable/empty `imageData` throws `InferenceError.adapterFailure` rather than fabricating a region — this is why `InferenceConformanceSuite.verifyOCRReturnsRegions` (frozen seam, `InferenceAPI`) had to change from a 3-arbitrary-byte fixture to a real embedded decodable PNG containing text: **`docs/adr/ADR-012-ocr-conformance-fixture.md`**, self-mergeable per ADR-008 once CI is green. `Scripts/import-allowlist.txt` gained `Vision CoreGraphics CoreImage CoreText ImageIO` for `InferenceHost`. New tests: `VisionOCRTests.swift` (recognizes rendered text end-to-end through the real client, honest-failure paths for undecodable/empty input, contrast-preprocessing decodability). All existing InferenceHost/InferenceAPI tests pass unmodified.

**Still not done (next iteration's scope, same iterative-delivery pattern as P1-16):**
- Per-run/response-level detected-language field — Vision's `automaticallyDetectsLanguage` improves recognition quality but doesn't expose a per-run language code on `VNRecognizedText`; surfacing "detected language" per the task's Requirements would need `NLLanguageRecognizer` post-processing plus a new `OCRResponse`/`OCRTextRegion` field, which is its own frozen-seam ADR — deliberately not bundled with ADR-012 above so each frozen-seam PR stays reviewable as one change.
- Batch (background-queue) vs. single-page (interactive) mode: `OCRRequest.priority` + `InferenceHostClient`'s existing interactive/background router dispatch already covers this at the plumbing level (P1-12); no OCR-specific batching work was needed or done.
- "Make Searchable" document action (OCR all raster pages → invisible text layer → atomic save) — text-layer write lives in `DocEngineHost`, which P1-16 (in-progress) currently holds as its `[INTEGRATION]` surface; per `docs/AGENT_LOOP.md` §2 primary-package isolation, this task's `DocEngineHost` scope is blocked until P1-16 merges or that claim is released. Not started.
- NFR-A3 accuracy bench suite + fixture manifest (300-dpi set, phone-photo set) + bench trend dashboard entry — no OCR ground-truth fixture corpus exists yet in `Fixtures/`; building one (synthetic generator + manifest rows, per CLAUDE.md §6 "fixtures are data-driven") is substantial standalone scope, not started. `Scripts/bench.sh` has no `ocr-accuracy` suite yet.
- 12-language smoke set — not started, depends on the fixture corpus above.
- Fixtures README OCR ground-truth format doc — deferred with the fixture corpus work above (nothing to document yet).

## Journal

**Orient:** read root CLAUDE.md, this task file, `Packages/InferenceHost/CLAUDE.md`, `Packages/InferenceAPI/CLAUDE.md`, existing `VisionAdapter.swift` (explicitly a P1-13 stub), `InferenceHostClient.swift`, `CoreMLAdapter.swift`/`NLEmbeddingProvider.swift` (precedent for a real-backend-behind-a-stub-interface swap), `InferenceConformanceSuite.swift`, `FakeInferenceClient.swift`, `TestSupport.swift`.

**Plan:** (1) real `VisionOCRProvider` using Vision + CoreGraphics/ImageIO/CoreImage, mapped into existing OCR DTOs — no DTO shape change needed for MVP since `NormalizedRect` already covers axis-aligned regions. (2) discovered the frozen conformance suite's OCR fixture (3 arbitrary bytes) is structurally impossible for a real adapter to satisfy honestly — either fabricate (red-line violation) or fix the fixture (frozen-seam ADR). Chose the ADR path (ADR-012), scoped to the fixture literal only, no protocol/DTO change. (3) tests: reuse the same "render real text, decode, recognize" technique for both the frozen fixture and the InferenceHost-level tests. (4) `DocEngineHost` text-layer-write half of the task is blocked by P1-16's live `[INTEGRATION]` claim on that package — confirmed via `tasks/in-progress/P1-16-atomic-save-backups.md`, deferred rather than working around the isolation rule.

**Security/privacy self-audit:** this code touches image bytes passed by the caller (potentially scanned document/photo content) only in-memory, only within `Inference.xpc`'s process boundary (ARCHITECTURE.md §7.1) — no network calls (Vision recognition is on-device), no logging of recognized text or image bytes, no vault interaction. Vision's model assets are Apple OS frameworks, not a fetched/vendored pack, so `ModelRegistry`'s signature/checksum path is correctly bypassed here (same as `embed`), not weakened.

**Architecture self-review (§6):** (1) no type here duplicates an API-package concept — `VisionOCRProvider.TextRun` is an internal implementation detail, not exposed outside `InferenceHost`. (2) no logic placed in a layer that will need moving — recognition + the top-left/bottom-left coordinate conversion both belong in the adapter, same place `CoreMLAdapter`/`NLEmbeddingProvider` put their real-backend logic. (3) ARCHITECTURE.md doesn't need editing — §7.1 already designates Vision as the OCR path.
