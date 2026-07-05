# InferenceService (.xpc)

Thin XPC bundle main over its host package. No network entitlement — ever (Constitution Art. 11).

**Current state (P1-12):** a standalone SwiftPM package, not yet the real `.xpc` bundle target — that packaging/embedding work is P0-07's (the Xcode app target), same gap `Services/DocEngineService` documents. `main.swift` proves `Packages/Platform`'s XPC transport links and runs correctly in a real, separately-launchable/killable process via an in-process self-check on startup (prints `InferenceService self-check: OK` to stdout). It does not yet accept connections from another process — see `docs/adr/ADR-002-xpc-transport-topology.md`. The registry/router/memory-governor logic this service will eventually host lives in and is tested by `Packages/InferenceHost`.

**Verify:** `swift build --package-path Services/InferenceService && swift test --package-path Services/InferenceService` (wired into CI's `services` job, since this directory isn't part of the `Packages/*` matrix).

P1-08 (Vault) adds the sibling `VaultService` package following the same pattern.
