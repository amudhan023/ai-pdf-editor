---
type: package
title: InferenceAPI
description: Typed inference request/response contracts (OCR, classify, extract, embed, generate) — planned as a frozen seam, currently a placeholder stub.
tags: [package, api-contract, inference, ml, frozen-seam, stub]
implementation_status: scaffolded
---

# InferenceAPI

**Purpose (per its own `CLAUDE.md`, not yet realized in code):** typed inference request/response contracts — `ocr`, `classify`, `extract`, `embed`, `generate` — plus a `FakeInferenceClient`. Intended as a **frozen seam** like `PDFEngineAPI`/`VaultAPI` (changes would require an ADR).

## Current state

`Packages/InferenceAPI/Sources/InferenceAPI/InferenceAPI.swift` is a 4-line placeholder — no protocols, DTOs, or fake client exist yet. This is the API-contract counterpart to `InferenceHost` (also a stub — see [../engines/inference-host.md](../engines/inference-host.md)) and the future `Inference.xpc` service (also not scaffolded — see [../services/inference-service.md](../services/inference-service.md)).

## Design intent (from `docs/ARCHITECTURE.md` §7)

Typed endpoints, not "run a model": callers ask for e.g. `embed(labels:context:)`, never name a model file — a `Model Registry` maps capability to the best installed model for the hardware tier. Planned capabilities: OCR + text geometry (Vision), barcode/MRZ, document classification (Core ML), layout/visual field detection (Core ML), NER/entity extraction (Core ML), label embeddings for semantic matching (Core ML, always-available matcher), and an LLM path (Apple Foundation Models on-device where available, else an opt-in downloadable pack) reserved for ambiguous/composite tiebreaks only — per the "deterministic first, small model second, LLM last" principle (root CLAUDE.md §2, §19).

## Allowed imports

Foundation only (per its `CLAUDE.md`, matching the other `*API` packages' Foundation-only discipline).

Consumed by (once built): `AutofillEngine`, `IngestionPipeline`, `InferenceHost` (all currently stubs).
