---
type: index
title: Vaultform OKF Index
description: Entry map for the Vaultform codebase knowledge bundle — start here, then drill into the linked sub-indexes.
tags: [overview, entry-point, vaultform]
---

# Vaultform — Open Knowledge Format Bundle

Vaultform is a native macOS PDF editor with a privacy-first, local-only AI Autofill Assistant. Personal data lives in an encrypted local vault; PDF forms (including scanned/flat ones) are filled from it with full user review and zero network dependency. Full product framing lives in `docs/PRD.md`; full architecture in `docs/ARCHITECTURE.md`; the fifteen immutable rules in `docs/CONSTITUTION.md`.

This bundle reflects repo state as of commit `efb6f4f` (2026-07-04). **This is an early-stage codebase**: a handful of packages have real, substantive implementations; most are still single-file scaffolds waiting on their task to be picked up. Every concept file below carries an `implementation_status` in its frontmatter (`implemented` / `partial` / `scaffolded` / `planned`) — trust that field over any prose describing "what a package does," since prose often describes the *design intent* (from ARCHITECTURE.md) rather than code that exists yet.

## How to use this bundle

Start at whichever sub-index matches what you're trying to understand, not necessarily in the order listed:

| Directory | Covers | Start here if you want to know... |
|---|---|---|
| [architecture/](architecture/index.md) | Product truths, layering, process topology, security model, storage, tech choices | "How is this system supposed to fit together, and why?" |
| [packages/](packages/index.md) | The frozen `*API` contract packages + implemented infra (PolicyKit, Platform) | "What are the actual typed contracts between components?" |
| [services/](services/index.md) | The three `.xpc` service processes and the transport between them | "How do processes talk to each other, and what runs where?" |
| [sessions/](sessions/index.md) | Application-layer workflow state machines | "Where does user-facing workflow state live?" |
| [engines/](engines/index.md) | Domain engines and infra host adapters | "Where does the actual matching/extraction/rendering logic goes?" |
| [ui/](ui/index.md) | Presentation-layer packages | "What UI surfaces exist?" |
| [workflows/](workflows/index.md) | Cross-component sequence flows (ingestion, autofill) | "What's the end-to-end path data takes?" |

## Ground truth outside this bundle

This bundle is a map, not a replacement for the territory. For anything load-bearing, the repo's own docs outrank it:

- `docs/CONSTITUTION.md` — fifteen immutable articles; outranks everything, including this bundle
- `CLAUDE.md` (repo root) — the operating manual: engineering principles, architecture rules, coding standards, DoD
- `docs/ARCHITECTURE.md` — full system design; source for most of `architecture/`
- `docs/REPO_STRUCTURE.md` — why the repo is laid out this way
- `docs/specs/vault-schema.md`, `docs/specs/policy-decision-table.md` — canonical catalogs (field paths, policy rules)
- Each package's own `Packages/<Name>/CLAUDE.md` — purpose, invariants, forbidden imports, gotchas, kept ≤60 lines and updated in the same PR as behavior changes

## Implementation snapshot (as of this bundle's writing)

**Substantively implemented:** `PDFEngineAPI`, `VaultAPI`, `PolicyKit`, `Platform`'s XPC transport layer.
**Skeleton/self-check only:** `Services/DocEngineService`.
**4-line placeholder stubs (no real logic yet):** `AutofillEngine`, `IngestionPipeline`, `DocumentSession`, `AutofillSession`, `IngestionSession`, `VaultManagerUI`, `PrivacyDashboard`, `VaultStore`, `DocEngineHost`, `InferenceHost`, `FormKnowledge`, `AuditLog`, `InferenceAPI`.
**Not yet scaffolded at all:** `App/` (composition root — no Swift files exist), `Services/InferenceService`, `Services/VaultService` (README only).
