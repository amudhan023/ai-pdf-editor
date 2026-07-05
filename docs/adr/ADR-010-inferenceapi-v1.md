# ADR-010 — InferenceAPI v1 (Freeze Point)

**Status:** Accepted · **Task:** P1-12

**Numbering note:** the task file names this `ADR-008-inferenceapi-v1.md`, but ADR-008 was taken by the agent self-merge policy (landed after P1-12 was filed). Using the next free number instead; no content conflict, just a stale reference in the task file.

## Context
ARCHITECTURE.md §7.2 designates `Inference.xpc` as the sole home for ML inference, exposed to every AI feature (OCR, classify, embed, NER, generate) as typed endpoints — call sites never name a model file (CLAUDE.md §19). `Packages/InferenceAPI` is the Track C freeze point analogous to `VaultAPI` (ADR-007) and `PDFEngineAPI` (ADR-006): Track C consumers build against these types once landed, so a further change is a breaking-contract event requiring a superseding ADR, not a silent edit.

## Decision
Freeze the following as InferenceAPI v1 (`Packages/InferenceAPI/Sources/InferenceAPI/`):

- **Capability/tier/priority enums:** `InferenceCapability` (ocr/classify/extractEntities/embed/generate — the closed set of endpoints), `HardwareTier` (appleSilicon/intel), `InferencePriority` (interactive/background — interactive preempts background per ARCHITECTURE.md §7.2).
- **Request/response DTOs**, one pair per capability (`OCRRequest`/`OCRResponse`, `ClassifyRequest`/`ClassifyResponse`, `ExtractEntitiesRequest`/`ExtractEntitiesResponse`, `EmbedRequest`/`EmbedResponse`, `GenerateRequest`/`GenerateResponse`), each carrying an `InferencePriority` so the router can dispatch without inspecting payload contents. `NormalizedRect` is the shared 0...1-normalized bounding-box shape OCR/extraction responses use (resolution-independent, matches `PDFEngineAPI`'s existing normalized-coordinate convention).
- **`ModelManifest`:** wire shape for a model pack's identity + integrity proof (modelID, capability, version, hardwareTier, `sha256Checksum`, detached `signature`, `estimatedMemoryBytes`). This package only describes a model pack — minting and verifying `signature`/`sha256Checksum` is `InferenceHost`'s job (`ModelRegistry`), identical split to `VaultAPI.PolicyTicket`/PolicyKit. See `docs/specs/model-pack-format.md` for the full wire format.
- **`InferenceError`:** typed error enum per CLAUDE.md §15 shape (`capabilityUnavailable`, `modelPackUnverified`, `modelPackNotFound`, `requestCancelled`, `memoryCapExceeded`, `adapterFailure`), each with a `userMessageKey`, `debugDescription`, and `InferenceErrorRecoverability` (retryable/userAction/fatal). Self-contained per module, same precedent as `VaultAPI`/`PDFEngineAPI` — no shared `VaultformError` protocol exists in the repo yet.
- **`InferenceClient` protocol:** one async throwing method per capability. No protocol-level bypass; every call is capability-scoped.
- **`FakeInferenceClient`:** an in-memory `actor` implementing `InferenceClient` with deterministic stub responses, shipped in the library per CLAUDE.md §5's `Fake*` convention.
- **`InferenceConformanceSuite`:** structural contract checks (response shape per request, not implementation quality) shipped in the library, so `InferenceHost`'s real client can run the identical suite `FakeInferenceClient` runs — this task's stated acceptance criterion.

## Consequences
- Any change to a protocol signature, DTO shape, or `ModelManifest`/`InferenceError` case listed above is a frozen-seam change: requires a superseding ADR + `[INTEGRATION]`-marked PR (root CLAUDE.md §3.6/§21) — not a normal task diff.
- `ModelManifest.signingPayload` (`modelID|version|sha256Checksum`) is the canonical byte sequence both `ModelRegistry` (verify) and any future signing tooling (mint) must agree on; changing the framing is a frozen-seam change even though the field itself is computed, not stored.
- No trusted signing key ships in this package — `InferenceHost.ModelRegistry` takes trusted public keys at `init`, since no real signed model pack exists yet (adapters are stubbed until P1-13+). Provisioning a production key is an open gap tracked in `docs/specs/model-pack-format.md`, not resolved by this ADR.
- `InferenceCapability`/`HardwareTier`/`InferencePriority` being `String`-backed, `CaseIterable` enums (rather than open string identifiers) means adding a new capability or hardware tier is itself a frozen-seam change, matching the "call sites never name a model file" invariant — the closed set is the contract.
