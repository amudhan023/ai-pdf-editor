# Model Pack Format & Verification

**Owner of this fact:** this document. `InferenceAPI.ModelManifest` (`Packages/InferenceAPI/Sources/InferenceAPI/ModelManifest.swift`) enforces the manifest's *shape*; `InferenceHost.ModelRegistry` (`Packages/InferenceHost/Sources/InferenceHost/ModelRegistry.swift`) enforces *verification*. This document is the canonical description of the wire format and the trust chain — CLAUDE.md §7.6: "never load a model from an unverified path."

Corresponds to ARCHITECTURE.md §7.2 (Model Registry: "capability → best installed model for hardware tier; refuses unverified model packs").

## Manifest shape

A model pack is described by an `InferenceAPI.ModelManifest`:

| Field | Type | Notes |
|---|---|---|
| `modelID` | `String` | stable identifier for one model build, e.g. `ocr-v1-applesilicon` |
| `capability` | `InferenceCapability` | one of `ocr`/`classify`/`extractEntities`/`embed`/`generate` |
| `version` | `String` | free-form, part of the signed payload |
| `hardwareTier` | `HardwareTier` | `appleSilicon` or `intel` — the registry only ever selects an exact tier match, never substitutes |
| `sha256Checksum` | `String` | lowercase hex SHA-256 of the model pack file's bytes |
| `signature` | `Data` | detached Ed25519 (Curve25519.Signing) signature over `signingPayload` |
| `estimatedMemoryBytes` | `Int` | declared resident footprint once loaded; the memory governor's caps are sized against this *declared* value, not a measured one, because eviction decisions must happen before loading |

## Signed payload

The signature is computed over `ModelManifest.signingPayload`:

```
"\(modelID)|\(version)|\(sha256Checksum)"
```

encoded as UTF-8 `Data`. Signing tooling and `ModelRegistry.register(manifest:packData:)` must agree on this exact framing — changing it is a frozen-seam change (ADR-010) even though the field is computed rather than stored.

## Verification (`ModelRegistry.register`)

1. Compute SHA-256 of the supplied `packData`; compare (constant-effort string compare, not timing-hardened — the pack file itself isn't secret) against `manifest.sha256Checksum`. Mismatch → `InferenceError.modelPackUnverified(reason: "checksum mismatch")`.
2. Verify `manifest.signature` against `manifest.signingPayload` using each key in `ModelRegistry`'s `trustedPublicKeys` (Curve25519.Signing, via CryptoKit). No key validates → `InferenceError.modelPackUnverified(reason: "signature verification failed")`.
3. Only on both checks passing is the manifest added to `manifestsByCapability` and the pack data retained — there is no partial registration of an unverified manifest.

`ModelRegistry.bestModel(for:tier:)` then does an exact hardware-tier match; a registry with no model for the caller's tier reports `InferenceError.capabilityUnavailable`, not a silent substitution.

## Trust key provisioning (open gap)

`ModelRegistry` takes its `trustedPublicKeys: [Curve25519.Signing.PublicKey]` as an `init` parameter rather than a hardcoded or bundle-embedded constant, because **no real signed model pack ships yet** — adapters (`VisionAdapter`/`CoreMLAdapter`/`FoundationModelsAdapter`) are stubs until P1-13+. Production key provisioning (where the trusted public key(s) come from at app launch, how the corresponding private key is custodied for signing releases, and rotation) is **not resolved by this document or by P1-12** — it is an open item for whichever task first bundles a real, signed model pack. Do not hardcode a placeholder key as if it were the production answer.

## What this format does not cover

- Model pack *contents* (Core ML `.mlmodelc` layout, tokenizer files, etc.) — that's an adapter concern (`CoreMLAdapter`/`VisionAdapter`), not the registry's.
- Download/distribution of packs — out of scope per CLAUDE.md §7.1 (no network calls); packs are bundled or side-loaded, never fetched.
- Model pack *removal/uninstall* UX — not yet designed.
