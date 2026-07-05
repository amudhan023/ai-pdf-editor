# P1-12 — Inference.xpc: Service, Model Registry & Memory Governor

**Owner:** claude-agent · **Branch:** task/P1-12-inference-service-registry · **Claimed:** ffa626bc67fd16bc72b585f0fe53d1573fd4e6b0

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

## Journal

### Orient
Read: root CLAUDE.md; this task file; `Packages/InferenceAPI/CLAUDE.md`, `Packages/InferenceHost/CLAUDE.md` (both still placeholder scaffolds); ARCHITECTURE.md §7.2 (Inference service design diagram + principles); `Packages/VaultAPI` in full (frozen-seam + FakeClient + ConformanceSuite precedent from P0-09, since InferenceAPI is the analogous freeze point for Track C) and its `ADR-007-vaultapi-v1.md`; `Packages/Platform`'s `XPC/XPCClient.swift`/`XPCServiceHost.swift` + `Services/DocEngineService` (P0-05's skeleton pattern — thin main proving Platform XPC linkage only, real cross-process wiring deferred to P0-07's app bundle, which doesn't exist yet); `Scripts/import-allowlist.txt`, `Scripts/check-boundaries.sh`, `Scripts/verify-integration.sh` (picks up `*ConformanceTests`/`*IntegrationTests` in `Packages/*` only, not `Services/*`).

Selection note: Phase 0's remaining backlog (P0-03/06/07) is blocked on `tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md` (unresolved, needs human ADR-001 decision on build-from-source vs. prebuilt-distribution). Per ROADMAP.md §3 ("tracks enter the next wave independently") and Phase 2's explicit no-phase-wide-gate precedent, selected P1-12 from Phase 1's independent inference track instead — its own Dependencies (P0-05) are in `done/`. Tie-broken over P1-08 (also Critical, also fully unblocked) by unblocking-power count (P1-12 is a dependency of 6 backlog tasks vs. P1-08's 5).

Environment note: `xcodebuild -version` shows Xcode 26.6 is now installed (`xcode-select -p` → `/Applications/Xcode.app/...`) — `Scripts/verify.sh InferenceAPI` ran its test step successfully. `tasks/escalations/E-002-no-xctest-without-xcode.md` no longer applies in this session; leaving that escalation file as historical record, not deleting it.

### Plan
1. `Packages/InferenceAPI` (frozen seam v1): `InferenceCapability`/`HardwareTier`/`InferencePriority` enums; DTOs for ocr/classify/extractEntities/embed/generate (Request+Response pairs); `ModelManifest` (checksum + detached signature shape, verification logic stays in InferenceHost — same split as VaultAPI/PolicyKit); `InferenceError` typed enum (CLAUDE.md §15 shape); `InferenceClient` protocol; `FakeInferenceClient` actor (deterministic stub responses); `InferenceConformanceSuite` shipped in the library (structural contract: response shape per request, not implementation quality).
2. `Packages/InferenceHost`: `HardwareTierDetector` (compile-time arch check); `ModelRegistry` actor (Curve25519 signature + SHA-256 checksum verification via CryptoKit — needs adding `CryptoKit` to InferenceHost's import-allowlist entry, precedented by PolicyKit's identical addition for VaultAPI ticket verification); `MemoryGovernor` actor (load/unload under a byte cap, evicts LRU); `InferenceRouter` actor (interactive/background priority queues; a running background op is cooperatively cancelled and re-queued when an interactive request arrives — idempotent retry, no partial-result corruption); stub `VisionAdapter`/`CoreMLAdapter`/`FoundationModelsAdapter` (real adapters are P1-13+); `InferenceHostClient` wiring registry+router+governor+adapters as the concrete `InferenceClient` used by the "real service" leg of the acceptance criteria.
3. `Services/InferenceService`: thin `main.swift` skeleton mirroring `Services/DocEngineService` exactly (Platform XPC self-check proof only — no real cross-process listener yet, that's still gated on P0-07).
4. Tests: InferenceAPI conformance suite run against both `FakeInferenceClient` and `InferenceHostClient`; `ModelRegistryTests` (tampered checksum/signature refused, typed error); `InferenceRouterIntegrationTests` (interactive preempts a running background op) named to be picked up by `verify-integration.sh`.
5. Docs: `docs/specs/model-pack-format.md` (manifest wire format + verification story); update `InferenceAPI`/`InferenceHost` `CLAUDE.md`s; new ADR — task file names it `ADR-008-inferenceapi-v1.md` but ADR-008 is already taken (agent-self-merge policy, landed after this task was written) — using the next free number, `ADR-010-inferenceapi-v1.md`, noting the drift in the ADR itself.
6. Risk: CryptoKit addition to InferenceHost's allowlist — mitigated by direct precedent (PolicyKit already imports CryptoKit for the identical PolicyTicket-signature-verification purpose); it's an Apple system framework already in `Package.resolved`-free use elsewhere, not a new third-party dependency under CLAUDE.md §17.

Acceptance-criteria mapping: (1) conformance suite green for both clients + tampered pack rejected → steps 1, 2, 4. (2) interactive preemption → steps 2, 4 (`InferenceRouterIntegrationTests`).

### Verify
- `Scripts/verify.sh InferenceAPI` → OK (build + test + boundaries).
- `Scripts/verify.sh InferenceHost` → OK (build + test + boundaries; `CryptoKit` allowlist addition holds).
- `Scripts/verify-integration.sh InferenceHost` → OK — picks up `InferenceRouterIntegrationTests` (preemption) and `InferenceHostClientConformanceTests` (real client vs. shared suite).
- `swift build`/`swift test --package-path Services/InferenceService` → OK (self-check + spawned-process integration test), not part of the `Packages/*` matrix so run directly.
- Consumers of the frozen seam rebuilt clean: `Scripts/verify.sh AutofillEngine`, `Scripts/verify.sh IngestionPipeline` (both only declare the `InferenceAPI` dependency in `Package.swift` so far, no source yet — additive change, no breakage).
- `swiftlint lint` over all touched paths: one `identifier_name` warning (loop variable `i` in `InferenceRouterIntegrationTests`), fixed by renaming to `iteration`; re-ran clean. Cosmetic `Package.swift` trailing-whitespace glitch in `InferenceHost/Package.swift` also cleaned up.

### Harden / Gate
- Re-read the diff as a hostile reviewer (CLAUDE.md §14): no dead code, no narrating comments, no force-unwraps/`try!` outside tests, no `DispatchQueue` (actors + async/await throughout).
- Error paths forced in tests: tampered checksum/signature (`ModelRegistryTests`), memory cap exceeded on an oversized single model (`MemoryGovernorTests`), capability unavailable on an empty registry (`InferenceHostClientConformanceTests`), request cancellation on preemption (`InferenceRouterIntegrationTests`).
- G4 judgment questions: (1) no type here duplicates an API-package concept — `InferenceHost` consumes `InferenceAPI`'s DTOs directly. (2) No logic placed in a layer that'll need moving later — verification stays in `InferenceHost` (registry), DTOs stay shape-only in `InferenceAPI`, matching the `VaultAPI`/PolicyKit precedent. (3) ARCHITECTURE.md §7.2 stays truthful — this *is* the described skeleton, adapters explicitly stubbed pending P1-13+.
- Security/privacy self-audit: touches no vault or document content; the only sensitive material is the model-pack integrity chain (checksum + Ed25519 signature), verified before any registration, never logged. No network paths added. `CryptoKit` is an Apple system framework already precedented in `PolicyKit`'s allowlist for the identical purpose — not a new third-party dependency under CLAUDE.md §17.
- Frozen-seam change: `InferenceAPI` is new (no prior consumers depend on removed shapes), so this is the *initial* freeze, not a breaking edit — `docs/adr/ADR-010-inferenceapi-v1.md` records it (numbered 010, not the task file's stale 008 reference, since ADR-008 was taken by the self-merge policy after this task was filed — noted in the ADR itself).
- Docs updated in this PR: both package `CLAUDE.md`s (already accurate, no changes needed — verified against actual imports/invariants), `docs/specs/model-pack-format.md` (new), `Services/InferenceService/README.md` (updated to reflect current skeleton state), `Scripts/import-allowlist.txt` (CryptoKit addition for InferenceHost).

### Outcome
All Definition of Done items satisfied: `verify.sh` green for all three primary surfaces (InferenceAPI, InferenceHost, Services/InferenceService), `verify-integration.sh InferenceHost` green, ADR-010 freeze record present, docs updated in-PR, no §7/§8 violations found in self-audit. Ready for PR (Step 7/8).
