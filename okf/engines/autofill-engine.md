---
type: engine
title: AutofillEngine
description: Field discovery, the dictionary→embeddings→LLM matching ladder, value formatting, and fill-plan construction. Never writes to documents. Currently a placeholder stub.
tags: [engine, domain-layer, autofill, matching, ml, stub]
implementation_status: partial
---

# AutofillEngine

**Purpose (per its `CLAUDE.md`, not yet realized in code):** field discovery (AcroForm path + a future visual-detection path), semantic matching, value formatting, and fill-plan construction (`FillPlan = [FieldProposal]`). Must never write into the document — only `AutofillSession` commits accepted proposals, through the doc engine ([../sessions/autofill-session.md](../sessions/autofill-session.md)).

## Current state

Partial (P1-14): `Matching/` holds the deterministic first rung of the matching ladder — `AliasDictionary` (+ bundled resources), `LabelNormalizer`, `AliasMatcher`, typed `AutofillEngineError`. Field discovery, embedding/LLM rungs, value formatting, and fill planning are still unbuilt (P2-01..P2-05 territory).

## Design intent (`docs/ARCHITECTURE.md` §4, §7.1)

Sub-components envisioned: `FieldDiscovery` (AcroForm reader + a beta-labeled `VisualFieldDetector` for flat/scanned forms), `SemanticMatcher` (consults `FormKnowledge` fingerprints *first*, then embeddings, then an LLM tiebreak only for ambiguous/composite cases — "deterministic first, small model second, LLM last," root CLAUDE.md §2/§19), `ValueFormatter` (dates, comb fields, enums, composites), `FillPlanner` (proposals + confidence, feeds `PolicyKit` for read grants). AcroForm field names hit a curated alias dictionary before any embedding runs at all.

## Allowed imports

Foundation, `PDFEngineAPI`, `VaultAPI`, `InferenceAPI`, `PolicyKit`, `FormKnowledge` — all of these except `PDFEngineAPI`/`VaultAPI` are themselves stubs today.
