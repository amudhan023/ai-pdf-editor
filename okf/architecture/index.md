---
type: index
title: Architecture Concepts Index
description: System-level design concepts — product truths, layering, process topology, security, storage, and technology choices.
tags: [architecture, overview]
---

# Architecture

Source of truth for everything here is `docs/ARCHITECTURE.md` (system design) and root `CLAUDE.md` (the operating rules derived from it). These concept files summarize and cross-reference rather than restate in full — read the source docs for the complete diagrams and rationale.

| Concept | What it covers |
|---|---|
| [five-product-truths.md](five-product-truths.md) | The 5 non-negotiable product truths every change is measured against |
| [layered-architecture.md](layered-architecture.md) | Presentation → Application → Domain → Infrastructure, and the import rules that enforce it |
| [process-topology.md](process-topology.md) | Main app + 3 sandboxed XPC services, trust posture per process |
| [module-map.md](module-map.md) | SPM package layout, ownership table, implementation status per package |
| [security-model.md](security-model.md) | Threat model, PolicyTicket mediation, SecureBytes, sandboxing |
| [key-hierarchy.md](key-hierarchy.md) | Secure Enclave → master key → derived keys, unlock/crypto-shred |
| [storage-layout.md](storage-layout.md) | On-disk container layout, conceptual vault schema |
| [technology-choices.md](technology-choices.md) | PDFium vs. alternatives, and the rest of the stack |
