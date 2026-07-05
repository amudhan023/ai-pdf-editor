---
type: package
title: FormKnowledge
description: Form fingerprinting, correction-derived mapping memory, and signed template packs — mappings and fingerprints only, never values. Currently a placeholder stub.
tags: [package, domain, forms, learning, stub]
implementation_status: scaffolded
---

# FormKnowledge

**Purpose (per its `CLAUDE.md`, not yet realized in code):** form fingerprinting (structure hash + fuzzy layout similarity), per-form mapping memory learned from user corrections, and bundled template packs for common forms. Must store mappings and fingerprints only — a value column in its DB would be an architecture violation (PRD FR-4.8).

## Current state

`Packages/FormKnowledge/Sources/FormKnowledge/FormKnowledge.swift` is a 4-line placeholder. No fingerprinting, mapping store, or template-pack loading exists yet.

## Design intent (`docs/ARCHITECTURE.md` §3.2, §4)

Consulted by `AutofillEngine`'s `SemanticMatcher` *before* any ML inference runs: a fingerprint hit yields a deterministic mapping, and models only fill the remaining gaps — both a quality floor and a latency win (dictionary/fingerprint hit ≈ no ML round-trip, serving the < 3s autofill budget). Storage is planned as `forms.db` (GRDB, plain SQLite — not encrypted, since it holds no values) with embeddings for field-alias/form-label similarity stored as BLOBs, searched via in-memory cosine.

## Allowed imports

Foundation, `PDFEngineAPI`, `VaultAPI`.

Consumed by (once built): `AutofillEngine` — itself currently a stub.
