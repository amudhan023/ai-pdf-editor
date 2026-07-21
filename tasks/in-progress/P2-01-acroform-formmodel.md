# P2-01 — AcroForm FormModel: Read & Write (Freeze Point)

**Epic:** E7 · **Primary package:** `Packages/DocEngineHost` (forms) + `Packages/PDFEngineAPI` (`FormField` extension, ADR-016) `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
Implement the PDFEngineAPI `FormModel`: parse AcroForm field trees (name, kind, rect, format hints, tooltip, tab order, current values) and write values back — the substrate for fill UI and autofill.

## Background
PRD FR-1.8; ARCHITECTURE.md freeze table: FormModel v1 unblocks P2-02/03/05 and FormKnowledge. Field-tree fidelity here bounds everything autofill can do — invest in the weird cases (inherited attributes, comb fields, radio groups with same names, JS format strings parsed as *hints* only).

## Requirements
- Read: full field tree incl. widget annotations, export values for checkboxes/radios, choice options, comb/maxlen, read-only/required flags, format/validation hints (safe subset — no JS execution).
- Write: set values with appearance-stream regeneration so filled forms render everywhere (NFR-C2); needAppearances handling.
- Field-change notifications to consumers; document-modified integration with save path.

## Dependencies
- P1-16.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/Forms/**`.

## Acceptance Criteria
- Fixture forms (W-9, I-9, DS-160-class, medical intake set) parse to trees matching expected-field manifests; values written by us render correctly in Acrobat and Preview.
- No JS execution pathway exists (security review checkbox).

## Definition of Done
- Global DoD, plus: FormModel v1 freeze noted in ADR-016 (this task file originally cited ADR-010, which is already taken by `docs/adr/ADR-010-inferenceapi-v1.md` — a stale reference, corrected here).

## Testing Requirements
- Tree-parity tests vs manifests; write→reopen→read equivalence; appearance snapshot tests; interop fixtures.

## Documentation Updates
- `DocEngineHost/CLAUDE.md` forms section; expected-field manifest format doc.

## Journal

**Orient/Plan (frozen-seam blocker, resolved):** `PDFEngineAPI.FormField` (frozen, ADR-006) as it stood couldn't carry export values, radio-group identity, choice options, or a required flag — all explicitly named in this task's own Requirements. Per CLAUDE.md §3.6/§3.7, a frozen-seam shape change needs an ADR before code, not a workaround. Wrote `docs/adr/ADR-016-pdfengineapi-formfield-export-values.md`: adds `exportValue`, `groupName`, `choiceOptions`, `isRequired` to `FormField`, all defaulted so the only existing call sites (`FakePDFEngine` + its tests, both in `PDFEngineAPI` itself) keep compiling unmodified — confirmed via `Scripts/verify.sh PDFEngineAPI` (OK). Per ADR-008 this is self-mergeable once the ADR is present and CI is green, so proceeding rather than escalating for human sign-off. Task reclassified `[INTEGRATION]` (now spans `PDFEngineAPI` + `DocEngineHost`) — also corrected this file's DoD line, which cited ADR-010 (already taken by `docs/adr/ADR-010-inferenceapi-v1.md`, unrelated); used ADR-016, the actual next-free number.

**Plan (DocEngineHost half):** `fpdf_formfill.h`/`fpdf_annot.h` are already vendored and in `CPDFium`'s modulemap — no new header needed. Field introspection/write requires an `FPDF_FORMHANDLE` from `FPDFDOC_InitFormFillEnvironment`, which needs a fully-populated `FPDF_FORMFILLINFO` callback struct (PDFium calls several fields unconditionally even for non-interactive use) — wrote `Forms/FormFillEnvironment.swift`, a no-op implementation of all ~29 callbacks (real signatures verified against the vendored header directly, several diverged from the doc-comment line count — e.g. `FFI_DoGoToAction` is 5 params not 6, `FFI_PopupMenu` takes an `FPDF_WIDGET` making it 6 not 8 — confirmed by bisecting `swift build` failures since Swift 6's diagnostic for a wrong `@convention(c)` closure signature inside a huge struct-literal initializer is unhelpful ("failed to produce diagnostic")). Plan for `Forms/PDFiumFormModel.swift`: `PDFiumEngine: FormModel` conformance — `fields(of:)` walks `FPDFPage_GetAnnotCount`/`GetAnnot` per page filtering to `FPDF_ANNOT_WIDGET` subtype, reads name/alt-name(tooltip)/type/value/flags/export-value/options via the `FPDFAnnot_GetFormField*`/`GetOption*` family; `setValue` finds the widget by name and calls the corresponding `SetFormField*`-family setter, following existing `PDFiumAnnotationStore` conventions (UTF-16LE buffer-length-then-fill pattern, typed `PDFEngineError`). Comb/maxlen already fit in `FormatHint` (no gap). Radio-group `groupName`: PDFium enumerates each radio widget as a distinct field by its own fully-qualified name when siblings differ only by `/AS`; grouping widgets that share a `/Parent` field name via `FPDFAnnot_GetFormControlIndex`/`Count`. Format-hint JS strings (if any `/AA` action exists) are read as inert strings only — no JS engine is even compiled into this vendored PDFium build (`pdf_enable_v8=false`), so evaluation is structurally impossible, not just avoided by convention. Fixtures: no real W-9/I-9/DS-160/medical-intake PDFs exist in `Fixtures/` yet (checked) — building synthetic AcroForm PDFs (via PDFium's own edit API, matching the existing annotation-fixture-building pattern) that exercise text/comb/checkbox/radio-group/choice-field/required-flag is the pragmatic scope, not a byte-for-byte real-form replica; documented as a scope interpretation, not silently narrowed.
