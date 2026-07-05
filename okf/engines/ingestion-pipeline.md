---
type: engine
title: IngestionPipeline
description: The document-ingestion stage graph — normalize → OCR → classify → extract → map → conflict-detect. Emits candidates only, never writes the vault. Currently a placeholder stub.
tags: [engine, domain-layer, ingestion, ocr, extraction, stub]
implementation_status: scaffolded
---

# IngestionPipeline

**Purpose (per its `CLAUDE.md`, not yet realized in code):** the document-ingestion stage graph: normalize → OCR → classify → extract → map → conflict-detect. Emits `ExtractionCandidate[]` only — never writes to the vault itself; that's exclusively `IngestionSession`'s job after user review ([../sessions/ingestion-session.md](../sessions/ingestion-session.md)).

## Current state

`Packages/IngestionPipeline/Sources/IngestionPipeline/IngestionPipeline.swift` is a 4-line placeholder. No stage graph or extractors exist yet.

## Design intent (`docs/ARCHITECTURE.md` §4, §5.1)

Sub-components envisioned: `Normalizer`, `Classifier` (document type detection), `Extractors` (MRZ parser, PDF417 barcode, NER, AcroForm value extraction — a mix of deterministic parsers and ML calls), `SchemaMapper` (extracted values → `FieldPath`s), `ConflictDetector` (uses `VaultClient.compareRead` to detect a mismatch against existing vault data without ever reading the existing value in full). See [../workflows/ingestion-flow.md](../workflows/ingestion-flow.md) for the full sequence this feeds into.

## Allowed imports

Foundation, `PDFEngineAPI`, `VaultAPI`, `InferenceAPI` — the latter two are themselves stubs today (VaultAPI's types are real; InferenceAPI is not).
