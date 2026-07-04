# P2-01 — AcroForm FormModel: Read & Write (Freeze Point)

**Epic:** E7 · **Primary package:** `Packages/DocEngineHost` (forms) · **Complexity:** L · **Priority:** Critical

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
- Global DoD, plus: FormModel v1 freeze noted in ADR-010.

## Testing Requirements
- Tree-parity tests vs manifests; write→reopen→read equivalence; appearance snapshot tests; interop fixtures.

## Documentation Updates
- `DocEngineHost/CLAUDE.md` forms section; expected-field manifest format doc.
