# P1-12 — Inference.xpc: Service, Model Registry & Memory Governor

**Epic:** E10 · **Primary package:** `Packages/InferenceHost` + `Services/InferenceService` + `Packages/InferenceAPI` `[INTEGRATION]` · **Complexity:** L · **Priority:** Critical

## Goal
The inference service skeleton per ARCHITECTURE.md §7.2: typed capability endpoints (InferenceAPI package — a freeze point), request router with interactive/background queues, model registry with signature+checksum verification, memory governor, hardware-tier detection.

## Background
Every AI feature (OCR, classify, embed, NER, generate) is a typed endpoint here; call sites never name model files. No network entitlement; read-only model dir.

## Requirements
- `Packages/InferenceAPI`: request/response types for ocr/classify/extractEntities/embed/generate + `FakeInferenceClient` (this is the Track C freeze point — API review required).
- Registry: capability → best installed model for hardware tier; refuses unverified model packs; bundled-model manifest format.
- Router: priority queues (interactive preempts background), cancellation, per-request memory accounting; governor loads/unloads Core ML models under caps.
- Adapters wired but stubbed: Vision adapter (real in P1-13), Core ML adapter, FoundationModels availability probe.

## Dependencies
- P0-05.

## Files Likely Affected
- `Packages/InferenceAPI/**`, `Packages/InferenceHost/**`, `Services/InferenceService/**`.

## Acceptance Criteria
- Fake + real service both pass InferenceAPI conformance suite; tampered model pack is refused with typed error.
- Interactive request preempts a running background batch in integration test.

## Definition of Done
- Global DoD, plus: ADR-008-inferenceapi-v1.md freeze record.

## Testing Requirements
- Registry/verification unit tests; queue-priority integration tests; memory-cap tests with synthetic large models.

## Documentation Updates
- Package `CLAUDE.md`s; docs/specs/model-pack-format.md.
