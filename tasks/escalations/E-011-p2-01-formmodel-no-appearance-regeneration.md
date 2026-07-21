# E-011 — P2-01: `FormModel.setValue` writes the field value but doesn't regenerate the appearance stream

**Status:** Open (documented scope cut, not blocking)
**Raised by:** P2-01 (AcroForm FormModel: Read & Write)
**Related:** ADR-016, `docs/adr/ADR-006-pdfengineapi-v1.md`

## Summary

P2-01's NFR-C2 acceptance criterion requires "values written by us render correctly
in Acrobat and Preview." `PDFiumFormModel.setValue` correctly sets the field's
logical value (`/V`, and `/AS` for checkboxes/radios) via `FPDFAnnot_SetStringValue`
and the equivalent setters — confirmed by reading the value back through this
engine's own `fields(of:)` and by a real save→reopen→read round trip
(`PDFiumFormModelTests`). What it does **not** do is regenerate the field's
appearance stream (`/AP`) or set the AcroForm dictionary's `/NeedAppearances` flag,
so a PDF viewer that renders the stored appearance stream rather than recomputing
it from `/V` (Preview and older Acrobat versions, per general PDF-viewer behavior)
would show the field's *old* rendered appearance even though the value changed.

Investigated (not assumed): grepped every vendored PDFium header
(`Packages/DocEngineHost/Sources/CPDFium/include/*.h`) for an appearance-regeneration
or `/NeedAppearances`-setting entry point. `fpdf_formfill.h` and `fpdf_doc.h`
mention `NeedAppearances` only in doc comments describing *reader* behavior, not as
a settable API. No `FPDFAnnot_SetAP`-equivalent exists for form fields (there is
one for markup annotations, `FPDFAnnot_SetAP`, used by `PDFiumAnnotationStore`, but
it sets a caller-supplied appearance stream — it does not *generate* one from a
field's current value/type/rect/font, which is what would be needed here).

## What P2-01 did instead

- `setValue`'s typed contract and tests describe exactly what it guarantees today:
  the logical value is set and durable across save/reopen, read back correctly by
  this engine. Nothing claims visual-rendering correctness.
- Did not fabricate an appearance-stream generator by hand (font metrics, text
  layout, comb-cell distribution, checkbox glyph selection) — that's a real,
  non-trivial rendering subsystem in its own right, not a one-off gap-filler for
  this task.

## Path to resolution

Two options for whoever picks this up (P2-02 form-fill-ui or a dedicated follow-up):
1. Set the AcroForm dictionary's `/NeedAppearances` boolean directly via the
   generic low-level dictionary-write API PDFium exposes for annotations
   (`FPDFAnnot_SetNumberValue`-equivalent at the document/AcroForm-dict level, if
   one exists — not yet confirmed to exist at that level, only at the annotation
   level) — cheapest fix if it works, since most modern viewers respect the flag
   and regenerate appearances themselves on open.
2. If no such accessor exists, this needs `FPDF_FFLDraw`-based appearance
   generation (render each filled widget through the form-fill environment this
   task already stood up in `FormFillEnvironment.swift` and use PDFium's own
   drawing path to produce the `/AP` stream) — more invasive, likely its own task.

Until resolved, this is a known, load-bearing gap for any feature that fills forms
and expects the result to look right outside this app's own renderer — flag it
prominently in P2-02/P2-05's task Journals rather than rediscovering it.
