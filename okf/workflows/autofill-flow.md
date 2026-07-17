---
type: workflow
title: Autofill Flow (Vault → Form)
description: The sequence by which vault data is proposed into a form, gated entirely by user review and PolicyKit grants.
tags: [workflow, autofill, sequence, vault, forms]
implementation_status: planned
---

# Autofill Flow — Vault → Form

Design intent from `docs/ARCHITECTURE.md` §5.2. The coordinating `AutofillSession` is still a stub, so this sequence is not executable end-to-end — but several steps now have real building blocks: the alias-matcher rung in `AutofillEngine` (step 3's deterministic half), the embed endpoint in `InferenceHost` (step 4), PolicyKit grants (step 5), and ticketed vault reads via `VaultStore` (step 6).

1. User clicks "Autofill" with a chosen profile (e.g. "Priya") on `AutofillSession`.
2. `AutofillSession` → `DocEngine.xpc`: get the `FormModel`. If an AcroForm is present, returns the typed field tree directly ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)'s `FormField`s). If the form is flat/scanned, falls back to `Inference.xpc` OCR + visual field detection instead (a beta-labeled path).
3. `AutofillSession` → `FormKnowledge`: fingerprint lookup. Returns cached field↔vault-path mappings if this exact form has been seen and corrected before.
4. `AutofillSession` → `Inference.xpc`: embed any still-unmapped field labels + surrounding context. Returns vault-path candidates + similarity scores.
5. `AutofillSession` → `PolicyKit`: request read grants for the matched paths. `PolicyRules.decide` runs — a `.sensitive`-tier field with stale auth returns `.requireReauth` rather than an outright grant or deny (see [../packages/policy-kit.md](../packages/policy-kit.md)).
6. `AutofillSession` → `Vault.xpc`: read the granted fields, carrying the minted `PolicyTicket`s. Returns values + provenance.
7. `AutofillSession` formats each value per field (`ValueFormatter`: dates, comb fields, enums).
8. `AutofillSession` presents the Review panel: proposals + confidence + source, per product truth 2 ([../architecture/five-product-truths.md](../architecture/five-product-truths.md)).
9. User accepts-all-high-confidence, edits per-field, or rejects.
10. `AutofillSession` → `DocEngine.xpc`: writes only the accepted values into the form fields — this is the *only* write path into the document for autofill-originated data.
11. `AutofillSession` → `FormKnowledge`: stores any corrected mappings (mappings only, never the values themselves — see [../packages/form-knowledge.md](../packages/form-knowledge.md)).
12. `AutofillSession` appends an `AuditLog` entry.
13. User saves/exports (flatten optional) → `DocumentSession`'s atomic save + versioned backup path runs ([../architecture/storage-layout.md](../architecture/storage-layout.md)).

**Quality/speed structure:** `SemanticMatcher` consults `FormKnowledge` *before* any ML call — a fingerprint hit yields a deterministic mapping and models only fill the remaining gaps. This is both a Risk-R2 fallback (flat-form quality) and the mechanism that keeps p50 autofill latency inside the < 3s budget ([../architecture/technology-choices.md](../architecture/technology-choices.md)'s embedding/ML choices exist specifically to serve this).
