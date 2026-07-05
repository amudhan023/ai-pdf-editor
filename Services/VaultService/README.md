# VaultService (.xpc)

Thin XPC bundle main over its host package. No network entitlement — ever (Constitution Art. 11).

**Current state (P1-08):** a standalone SwiftPM package, not yet the real `.xpc` bundle target — that packaging/embedding work is P0-07's (the Xcode app target), same gap `Services/DocEngineService`/`Services/InferenceService` document. `main.swift` proves `Packages/Platform`'s XPC transport links and runs correctly in a real, separately-launchable/killable process via an in-process self-check on startup (prints `VaultService self-check: OK` to stdout). It does not yet accept connections from another process — see `docs/adr/ADR-002-xpc-transport-topology.md`. The SQLCipher store, key hierarchy, and lock-state logic this service will eventually host lives in and is tested by `Packages/VaultStore`.

**Verify:** `swift build --package-path Services/VaultService && swift test --package-path Services/VaultService` (wired into CI's `services` job, since this directory isn't part of the `Packages/*` matrix).
