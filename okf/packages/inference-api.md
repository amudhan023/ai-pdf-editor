---
type: package
title: InferenceAPI
description: Typed inference request/response contracts (OCR, classify, extract-entities, embed, generate) plus FakeInferenceClient and a conformance suite — a frozen seam.
tags: [package, api-contract, inference, ml, frozen-seam]
implementation_status: implemented
---

# InferenceAPI

**Purpose:** typed inference request/response contracts — OCR, classify, extract-entities, embed, generate — plus a `FakeInferenceClient` and a conformance suite. A **frozen seam** like `PDFEngineAPI`/`VaultAPI` (changes require an ADR).

## Current state (P1-12)

Implemented in `Packages/InferenceAPI/Sources/InferenceAPI/`: `InferenceClient` (the protocol), per-capability request/response DTOs (`OCR.swift`, `Classify.swift`, `ExtractEntities.swift`, `Embed.swift`, `Generate.swift`), `InferenceCapability`, `ModelManifest` (the shape of the registry's signature/checksum contract), `NormalizedRect` (Foundation-only geometry), `InferenceError` (typed taxonomy), `FakeInferenceClient`, and `ConformanceSuite` (run against the fake and the real implementation alike, per the repo's conformance-suite testing pattern).

The real implementation is `InferenceHost` ([../engines/inference-host.md](../engines/inference-host.md)); the eventual process boundary is `Inference.xpc` ([../services/inference-service.md](../services/inference-service.md)), today a self-check skeleton executable.

## Design (from `docs/ARCHITECTURE.md` §7)

Typed endpoints, not "run a model": callers ask for e.g. `embed(labels:context:)`, never name a model file — a `Model Registry` maps capability to the best installed model for the hardware tier. Capabilities: OCR + text geometry (Vision), barcode/MRZ, document classification (Core ML), layout/visual field detection (Core ML), NER/entity extraction (Core ML), label embeddings for semantic matching (Core ML, always-available matcher), and an LLM path (Apple Foundation Models on-device where available, else an opt-in downloadable pack) reserved for ambiguous/composite tiebreaks only — per the "deterministic first, small model second, LLM last" principle (root CLAUDE.md §2, §19).

## Allowed imports

Foundation only (matching the other `*API` packages' Foundation-only discipline).

Consumed by: `InferenceHost` (implements it). Future consumers: `AutofillEngine`'s embedding rung and `IngestionPipeline` — today `AutofillEngine`'s only matcher rung is the deterministic alias dictionary, which doesn't call inference ([../engines/autofill-engine.md](../engines/autofill-engine.md)).
