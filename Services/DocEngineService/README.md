# DocEngineService (.xpc)

Thin XPC bundle main over its host package. No network entitlement — ever (Constitution Art. 11).

**Current state (P0-05):** a standalone SwiftPM package, not yet the real `.xpc` bundle target — that packaging/embedding work is P0-07's (the Xcode app target). `main.swift` proves `Packages/Platform`'s XPC transport links and runs correctly in a real, separately-launchable/killable process via an in-process self-check on startup (prints `DocEngineService self-check: OK` to stdout). It does not yet accept connections from another process — see `docs/adr/ADR-002-xpc-transport-topology.md` for why that specifically isn't achievable without P0-07's app bundle (empirically confirmed, not assumed).

**Verify:** `swift build --package-path Services/DocEngineService && swift test --package-path Services/DocEngineService` (wired into CI's `services` job, since this directory isn't part of the `Packages/*` matrix).

P0-06 (DocEngine render pipeline) replaces this skeleton's ping logic with real PDF rendering, once P0-03/PDFium is unblocked (`tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`). P1-08 (Vault), P1-12 (Inference) add sibling `VaultService`/`InferenceService` packages following the same pattern.
