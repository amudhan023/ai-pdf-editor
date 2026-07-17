---
type: engine
title: AutofillEngine
description: Field discovery, the dictionary→embeddings→LLM matching ladder, value formatting, and fill-plan construction. Never writes to documents. Alias-dictionary matcher rung implemented; the rest still unbuilt.
tags: [engine, domain-layer, autofill, matching, ml]
implementation_status: partial
---

# AutofillEngine

**Purpose:** field discovery (AcroForm path + a future visual-detection path), semantic matching, value formatting, and fill-plan construction (`FillPlan = [FieldProposal]`). Must never write into the document — only `AutofillSession` commits accepted proposals, through the doc engine ([../sessions/autofill-session.md](../sessions/autofill-session.md)).

## Current state (P1-14)

The first, fully deterministic rung of the matching ladder exists in `Sources/AutofillEngine/Matching/`: `LabelNormalizer`, `AliasDictionary` (curated field-name aliases → vault paths), `AliasMatcher`, and `AutofillEngineError`. AcroForm field names hit this dictionary before any embedding runs — the embedding rung's `embed` endpoint lives in `InferenceHost` ([inference-host.md](inference-host.md)) but isn't consumed here yet.

Not yet built: `FieldDiscovery`, the embedding/LLM matcher rungs, `ValueFormatter`, `FillPlanner`.

## Design intent (`docs/ARCHITECTURE.md` §4, §7.1)

Sub-components envisioned: `FieldDiscovery` (AcroForm reader + a beta-labeled `VisualFieldDetector` for flat/scanned forms), `SemanticMatcher` (consults `FormKnowledge` fingerprints *first*, then embeddings, then an LLM tiebreak only for ambiguous/composite cases — "deterministic first, small model second, LLM last," root CLAUDE.md §2/§19), `ValueFormatter` (dates, comb fields, enums, composites), `FillPlanner` (proposals + confidence, feeds `PolicyKit` for read grants).

## Allowed imports

Foundation, `PDFEngineAPI`, `VaultAPI`, `InferenceAPI`, `PolicyKit`, `FormKnowledge` — `FormKnowledge` is still a stub today.
