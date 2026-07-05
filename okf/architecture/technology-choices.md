---
type: architecture
title: Technology Choices
description: Why PDFium over PDFKit/commercial SDKs, and the rest of the stack — GRDB+SQLCipher, CryptoKit, Vision, Core ML, native XPC.
tags: [architecture, technology, pdfium, tradeoffs]
implementation_status: n/a
---

# Technology Choices

Full rationale in `docs/ARCHITECTURE.md` §10. These are recorded/seeded as ADRs (`docs/adr/`); revisiting any of them requires a superseding ADR, not a silent drift.

## PDF engine — the highest-stakes choice

| Option | Verdict |
|---|---|
| Apple PDFKit | Free, fast MVP viewer, but content editing is too weak — dead-ends the editor, which is a product pillar ([five-product-truths.md](five-product-truths.md) truth 4) |
| **PDFium (chosen)** | Battle-hardened parse/render (same engine as Chrome); editing primitives exist but a real text-editing layer must be built in-house — that build *is* the editor's competitive moat |
| Commercial SDK (Nutrient/PSPDFKit, ComPDFKit, Foxit) | Fastest to market, but $50–150K+/yr, roadmap-hostage, margin erosion, and some phone home (audit required) |
| Build from scratch | Rejected outright — multi-year effort |

**Decision:** PDFium core, wrapped behind `PDFEngineAPI` (an engine-neutral protocol layer — see [packages/pdf-engine-api.md](../packages/pdf-engine-api.md)) so a commercial-SDK escape hatch stays open if the in-house text-editing milestone slips, without it being a design compromise today. Recorded as ADR-001 (revisit gate: the P2-14 text-editing checkpoint).

## The rest of the stack

| Concern | Choice | Why not the alternative |
|---|---|---|
| Language/concurrency | Swift 6, strict concurrency, actors | Obj-C++ contained to the PDFium boundary only |
| UI | SwiftUI-first, AppKit where it earns it | Pure AppKit is slower to build; pure SwiftUI is still weak for pro document windows |
| Vault DB | GRDB + SQLCipher | Core Data/SwiftData: poor fit for custom crypto, opaque migrations, SwiftData too young for a security-critical store |
| Crypto | CryptoKit + Secure Enclave (`SecKey`) | libsodium adds another supply-chain dependency for no real gain here |
| OCR | Vision framework | Tesseract: worse real-world accuracy, larger binary |
| ML runtime | Core ML (ANE) + FoundationModels where present | MLX reserved for the optional big-model pack's internal runtime |
| Embedding search | In-memory cosine over GRDB-stored vectors | sqlite-vec/FAISS unjustified at this scale (a few hundred vault paths × a few thousand cached labels) |
| XPC | Native XPC with a Codable DTO layer | gRPC/local sockets: pointless overhead and extra entitlement surface on-device |
| Update/distribution | Mac App Store + direct notarized build with Sparkle 2 | Single-channel MAS alone risks the sandbox/distribution flexibility the roadmap wants from day 1 |

Every dependency beyond this approved set (GRDB, SQLCipher, PDFium pinned, Sparkle 2, existing swift-log-style utilities) requires an ADR covering license, supply-chain posture, binary size, and build-vs-buy cost (root CLAUDE.md §17, Constitution Article 7).
