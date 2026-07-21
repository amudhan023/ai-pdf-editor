# ADR-016 — PDFEngineAPI: `FormField` Gains Export Values, Choice Options, Required Flag, Radio-Group Identity

**Status:** Accepted · **Task:** P2-01 · **Amends:** ADR-006 (PDFEngineAPI v1 freeze)

## Context
P2-01 implements `FormModel` (`Packages/PDFEngineAPI/Sources/PDFEngineAPI/FormModel.swift`) against real AcroForm field trees. `FormField` as frozen by ADR-006 carries `name, page, rect, kind, formatHint, tooltip, tabOrder, isReadOnly, currentValue` — enough to *locate* a field and read/write its plain string value, but not enough to satisfy this task's own Requirements:

- **Checkbox/radio export values** (PDF `/AP`'s `/N` sub-dictionary keys, e.g. `/Yes`/`/Off`) — a checkbox's `currentValue` is meaningless without knowing what "on" is actually called; nothing on `FormField` carries it.
- **Radio-group identity** — multiple widget annotations sharing one field `name` form a radio group (ISO 32000-1 §12.7.4.2.3), each with its own export value. `FormField` has no way to represent "this field is one option among N in a shared group" versus an independent checkbox.
- **Choice options** (combo/list box `/Opt` array) — the field's selectable value list. Nothing on `FormField` carries it.
- **Required flag** (`/Ff` bit 2) — only `isReadOnly` (`/Ff` bit 1) exists.

This is a frozen-seam change (`Packages/PDFEngineAPI/`, ADR-006): additive only, same pattern as ADR-013/014/015.

## Decision
Add to `FormField`, all with defaults so every existing call site (`FakePDFEngine`, its tests) keeps compiling unmodified:

- **`exportValue: String? = nil`** — the "on" value for `.checkbox`/`.radioButton` kinds (PDF `/AP/N`'s non-`/Off` key); `nil` for `.text`/`.choice`/etc.
- **`groupName: String? = nil`** — for `.radioButton` fields, the shared field name all widgets in the group share (distinct from `FormField.name`/`id`, which per PDF spec must be **unique per widget** for radio buttons — PDFium enumerates each widget as its own field with its own fully-qualified name when siblings are distinguished by `/AS`/kids; `groupName` is that shared parent name). `nil` for every non-radio kind, and `nil` for a radio button PDFium reports as ungrouped.
- **`choiceOptions: [String] = []`** — `.choice`/`.listBox` option list, display-string order preserved; empty for every other kind (same "empty means not applicable" convention as `Annotation.quadPoints`/`inkPaths`, ADR-014/015).
- **`isRequired: Bool = false`** — `/Ff` bit 2.

No change to `FormFieldKind`, `FormatHint`, or the `FormModel` protocol's two methods — this ADR only widens what a `FormField` value can carry, not how it's fetched or written.

## Consequences
- `DocEngineHost.PDFiumEngine`'s `FormModel` conformance populates all four via PDFium's form-fill API (`fpdf_formfill.h`, already vendored) — `FPDFAnnot_GetFormFieldExportValue`/equivalent widget-level accessors for `exportValue`, sibling-widget grouping by shared field name for `groupName`, `FPDFAnnot_GetOptionCount`/`FPDFAnnot_GetOptionLabel` for `choiceOptions`, and the appropriate `/Ff` bit read for `isRequired`.
- `PDFEngineConformanceSuite` gains coverage for a checkbox/radio-group/choice-field fixture asserting these four fields round-trip through `fields(of:)`.
- Any further change to `FormField`'s field set or `FormModel`'s method signatures is itself a frozen-seam change requiring a superseding ADR.
- Self-mergeable once this ADR is present and CI is green, per ADR-008 (frozen-seam change, not an entitlement or governance-doc change).
