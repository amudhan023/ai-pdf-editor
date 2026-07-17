---
type: architecture
title: Process Topology
description: The main app process plus three sandboxed XPC services, their trust postures, entitlements, and crash blast radius.
tags: [architecture, xpc, process-isolation, security, sandboxing]
implementation_status: partial
---

# Process Topology

One app bundle, four OS processes connected by XPC (`docs/ARCHITECTURE.md` §2.3) — the macOS-native analog of Chrome/Preview's process isolation for untrusted content.

| Process | Trust posture | Entitlements | Crash blast radius | Current status |
|---|---|---|---|---|
| `Vaultform.app` (main) | Hosts UI + coordinators + domain services + the Policy & Trust layer | App Sandbox, network only for two toggleable app-level paths (update check, license validation) | N/A | `App/` is a real SwiftPM executable + composition root (P0-07); all engines still wired in-process, no `.xpc` bundles yet |
| `DocEngine.xpc` | **Hostile input** — parses arbitrary PDFs/DOCX/images | No network, no vault container; receives security-scoped file handles only; one instance *per open document* | Lost render of one document; auto-restart | Skeleton `main.swift` exists (self-check only, see [services/doc-engine-service.md](../services/doc-engine-service.md)); real PDFium wiring and `.xpc` bundle registration not built |
| `Inference.xpc` | Semi-trusted; processes extracted content | No network; read-only model directory; memory-capped | In-flight inference retried | Not scaffolded — `Services/InferenceService` has only a README |
| `Vault.xpc` | **Most privileged** — sole owner of vault DB and keys | No network; exclusive vault container access; talks only to the main app's Policy layer | Vault relocks; DB is transactional | Not scaffolded — `Services/VaultService` has only a README |

**Why three services, not one:** each has a distinct trust posture and blast radius (table above). The main app never links the PDF parser and never holds vault plaintext in bulk — it holds only the specific decrypted field values granted per operation via a `PolicyTicket` (see [security-model.md](security-model.md)).

**Cross-process communication:** typed, versioned, capability-scoped XPC — Swift protocols with `Codable` DTOs, no custom `NSSecureCoding` classes beyond the boundary. Bulk pixel data (rendered tiles) travels via `IOSurface` shared memory; everything else is small typed JSON messages inside an envelope. See [services/xpc-transport.md](../services/xpc-transport.md) for the actual implemented mechanism (`Packages/Platform/Sources/Platform/XPC/`).

**A documented, empirically-confirmed limitation today:** genuine cross-process XPC between two independently-spawned, non-launchd-registered processes does not work on this platform (`NSXPCListenerEndpoint` can only be encoded by `NSXPCCoder`; ad-hoc `machServiceName` listeners don't connect either). The transport layer's contract is proven via same-process anonymous `NSXPCListener`s, which *is* genuine XPC IPC, just not yet a different OS process — real multi-process operation needs a proper `.xpc` bundle embedded in the app target (task P0-07, not yet done). See ADR-002.
