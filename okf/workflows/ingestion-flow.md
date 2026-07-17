---
type: workflow
title: Ingestion Flow (Document → Vault)
description: The sequence by which an ingested document's extracted data reaches the vault, gated entirely by user review and PolicyKit.
tags: [workflow, ingestion, sequence, vault]
implementation_status: planned
---

# Ingestion Flow — Document → Vault

Design intent from `docs/ARCHITECTURE.md` §5.1. `IngestionSession` and `IngestionPipeline` are still stub packages, so this sequence is not executable end-to-end — but several steps now have real building blocks: Vision OCR in `InferenceHost` (step 3), and `compareRead`, PolicyKit-ticketed writes, batch accept-set commits, and audit-log appends via `VaultStore`/`AuditLog` (steps 6, 9–12).

1. User drops a document (e.g. `passport.pdf`) onto `IngestionSession`.
2. `IngestionSession` → `DocEngine.xpc`: parse + rasterize, using a security-scoped file handle. Returns page images + native text if any exists.
3. If scanned: `IngestionSession` → `Inference.xpc`: OCR pages. Returns text + geometry.
4. `IngestionSession` → `Inference.xpc`: classify document type (e.g. `passport`, confidence `0.97`).
5. `IngestionSession` → `Inference.xpc`: run extractors (deterministic MRZ parse + ML-based NER). Returns `ExtractionCandidate[]` (value, region, confidence).
6. `IngestionSession` → `Vault.xpc`: `compareRead` with a compare-only grant — reads current field summaries (presence/sensitivity/fingerprint) without disclosing existing values, to support conflict detection.
7. `IngestionSession` runs conflict detection locally, then presents the Review UI: candidates + source snippets, side-by-side with any detected conflicts.
8. User accepts / edits / rejects each candidate.
9. `IngestionSession` → `PolicyKit`: requests a write grant for the accepted set. `PolicyRules.decide` runs (see [../packages/policy-kit.md](../packages/policy-kit.md)) — an `.ephemeral`-mode session denies this outright regardless of anything else.
10. `PolicyKit` (having granted) → `Vault.xpc`: write fields + provenance, carrying the minted `PolicyTicket`.
11. `Vault.xpc` commits the write as one transaction, confirms back.
12. `IngestionSession` appends an `AuditLog` entry (IDs only, never values).

**Ephemeral mode:** skips step 9 onward entirely — accepted candidates live only in session memory and are never persisted, enforced structurally by `PolicyRules`' ephemeral-write-always-denies rule (row 1 of the decision table), not by session-level discipline alone.

See [../packages/vault-api.md](../packages/vault-api.md) for the `FieldSummary`/`compareRead` shapes and [../architecture/security-model.md](../architecture/security-model.md) for the ticket-mediation guarantee underneath step 10.
