# P3-01 — Visual Field Detection (Flat/Scanned Forms)

**Epic:** E12 · **Primary package:** `Packages/AutofillEngine` (visual path) + layout model in `Packages/InferenceHost` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
Detect fillable fields on forms with no AcroForm: labels, blank lines, boxes, comb rows, checkbox glyphs — producing an inferred field tree compatible with the AcroForm pipeline (PRD FR-4.1 flat path, the R2 bet).

## Background
ARCHITECTURE.md §7.1 layout model (LayoutLM-class distilled, Core ML). Output feeds the same matcher/formatter/planner unchanged — this task is detection only. Beta-label decision rides on the NFR-A2 bench (≥85% field-level recall) at M5.

## Requirements
- Layout endpoint in Inference.xpc (registry-managed model pack): page image + OCR geometry → field candidates (kind, rect, associated label text, group hints for radio/checkbox clusters).
- Post-processing: label-field association heuristics, comb-row segmentation, table-form handling, confidence per field.
- Adapter: candidates → PDFEngineAPI-compatible inferred `FormModel` (marked `inferred: true` so review UI can badge the beta path).
- Fill rendering for inferred fields = positioned text/check annotations (flatten-ready), since there are no real widgets.

## Dependencies
- P1-13, P2-03 (consumes matcher), P1-12; benchmark set from P0-08 (flat-form subset).

## Files Likely Affected
- `Packages/InferenceHost/Sources/Layout/**`; `Packages/AutofillEngine/Sources/VisualFields/**`.

## Acceptance Criteria
- NFR-A2 bench: ≥85% field-level recall on the flat-form benchmark set — or documented shortfall triggering PRD beta-label plan.
- End-to-end: scanned medical-intake fixture → detected fields → fill via existing planner (integration test).

## Definition of Done
- Global DoD, plus: bench results memo for the M5 beta-label go/no-go.

## Testing Requirements
- Detection bench vs annotated flat-form manifests; association-heuristic unit tests; degraded-scan robustness set.

## Documentation Updates
- docs/specs/flat-form-detection.md (model card, known failure modes).
