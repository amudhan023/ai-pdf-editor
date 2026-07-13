# ADR-012 — InferenceConformanceSuite OCR Fixture: Real Decodable Image

**Status:** Accepted · **Task:** P1-13 · **Amends:** ADR-010 (InferenceAPI v1 freeze)

## Context
`InferenceConformanceSuite.verifyOCRReturnsRegions` (`Packages/InferenceAPI/Sources/InferenceAPI/ConformanceSuite.swift`) is a frozen-seam file (ADR-010): it must pass identically against `FakeInferenceClient` and any real `InferenceClient`. Until P1-13, the only real-ish adapter was `InferenceHost.VisionAdapter`'s stub, which returned a fixed region for any non-empty `imageData` — so the suite's fixture, `Data([0x01, 0x02, 0x03])` (three arbitrary bytes, not a valid image), was sufficient to exercise it.

P1-13 replaces the stub with a real `VisionOCRProvider` backed by `VNRecognizeTextRequest`. Three arbitrary bytes do not decode as an image (`CGImageSourceCreateImageAtIndex` returns `nil`), so a real adapter can only either (a) throw on undecodable input, or (b) fabricate a region to keep the old fixture "passing." (b) is a red-line violation (CLAUDE.md §2 "honest failure... never silently guess, especially in autofill and text editing"; §19 forbids structurally-possible hallucination) — fabricating recognized text for input that isn't even a decodable image is the exact failure mode those rules exist to prevent. (a) is correct behavior but breaks the suite's current fixture, since `verifyOCRReturnsRegions` expects a *successful* call with `>= 1` region.

## Decision
Replace the suite's OCR fixture with the bytes of a small, real, decodable PNG image containing the rendered word "HELLO" (generated once via CoreGraphics/ImageIO, embedded as a base64 `Data` literal in `ConformanceSuite.swift`). The suite still imports only `Foundation` (`Data(base64Encoded:)`) — no new dependency, no frozen-seam shape change to any protocol/DTO, only the literal test input changes.

This lets the suite assert what it was always meant to assert — "a real adapter returns >=1 region with confidence in `0...1`" — using an input a real OCR engine can honestly satisfy, instead of an input that only a fabricating stub could satisfy. `FakeInferenceClient.ocr` is unaffected: it returns a fixed region regardless of input bytes.

## Consequences
- `VisionOCRProvider`/`VisionAdapter` (`InferenceHost`) can throw `InferenceError.adapterFailure` for genuinely undecodable `imageData` without failing conformance — the suite no longer asks a real implementation to fabricate output.
- Any future capability whose conformance fixture assumes "any non-empty bytes succeed" should be reviewed against this same failure mode before its stub is replaced with a real backend.
- Self-mergeable once this ADR is present and CI is green, per ADR-008 (frozen-seam change, not an entitlement or governance-doc change).
