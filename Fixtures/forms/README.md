# forms — populated by P0-08. NO REAL PII (Constitution Art. 15).

Top-target-forms set for the autofill matcher/fill-planner benches:
field-name -> canonical vault-path mappings, per `manifest.json`.

## What's here (v1 starter set, not the full target)

5 real AcroForms (IRS W-9, W-4, 1040, 4506-T; USCIS I-9) — the same 5 files
as `Fixtures/pdf-corpus/starter/` (referenced by relative path, not
duplicated, to avoid two LFS-tracked copies of identical bytes). The task's
original acceptance criterion was >=25 of the top-100 target forms
(IRS/USCIS/SF-86-class/medical intake). This is 5, all IRS/USCIS. See
`tasks/escalations/E-005-corpus-acquisition-gap.md` and
`docs/specs/corpus-plan.md`.

## `vault_path` is provisional

`Schemas/vault-schema.yml` (the frozen canonical field-path catalog) is still
empty — it's populated by P0-09 (Vault API package), which had not landed as
of this task. Every `vault_path` in `manifest.json` follows the
dot-separated-lowercase convention (root CLAUDE.md SS5) but is a **proposal**,
not a ratified path. Reconcile against `docs/specs/vault-schema.md` once
P0-09 lands — expect renames, not structural rework, since the mappings were
built field-by-field against real form semantics.

## How the mappings were verified

`field_name` values are the PDF's real AcroForm field names (via a one-time
PDFKit widget-annotation walk — see `Fixtures/pdf-corpus/README.md` for why
PDFKit, not PDFium, is fine here). Two of the five forms (W-9, W-4, 1040) use
opaque XFA-style field names (`f1_01`, `c1_1`, ...) with no embedded label, so
each was cross-checked by rendering the page to PNG with PDFKit and visually
matching field bounds (x, y) to the on-page label — not guessed from the
field name alone. The other two (4506-T, I-9) have either real `/TU` tooltip
text or already-descriptive field names, which is called out per form in
`manifest.json`'s `verification_method`.

## Coverage is partial by design

Only identity/contact/address/filing-status fields are mapped — not every
checkbox or computed amount on every form (1040 alone has ~199 fields; its
income lines are computed tax amounts, not vault-sourced data, so they're out
of scope for autofill regardless of corpus size). I-9 Section 2 (employer's
List A/B/C document verification) depends on a runtime choice of which
document the employee presented, which needs FillPlanner-level conditional
logic (P2-05), not a static manifest row — deferred, noted in the manifest.
