---
type: architecture
title: Storage Layout
description: The on-disk container layout and the conceptual vault schema shape — what's stored where, and why relational over document-store.
tags: [architecture, storage, vault-schema, sqlcipher, grdb]
implementation_status: planned
---

# Storage Layout

Design from `docs/ARCHITECTURE.md` §8. Not yet implemented — depends on `VaultStore`, `FormKnowledge`, and `AuditLog`, all still stub packages.

## Container layout

```
~/Library/Containers/com.vaultform.app/Data/
├── Vault/                # owned exclusively by Vault.xpc
│   ├── vault.db          # SQLCipher (AES-256): profiles, fields, provenance, history, relationships
│   ├── attachments/      # per-file AES-256-GCM encrypted originals
│   └── backups/          # rolling encrypted snapshots (local)
├── FormKnowledge/
│   └── forms.db          # GRDB (plain SQLite): fingerprints, mappings, template packs — NO values
├── Models/                # read-only signed model packs
├── AuditLog/
│   └── audit.log          # append-only, hash-chained, no values
├── DocumentBackups/        # versioned copies of edited PDFs (opt-out)
└── Scratch/                # session-keyed encrypted temp; purged on session end
```

User documents themselves stay wherever the user keeps them (security-scoped bookmarks for recents) — they are never imported into the app's container.

## Conceptual vault schema

- `persons` (id, kind: person|organization, relationships as typed edges)
- `sections` → `fields` (id, person_id, path e.g. `identity.passport.number`, type, value_ciphertext, sensitivity, aliases, verified_at)
- `history_entries` — first-class (not JSON blobs), because gap-detection queries need date-range structure
- `provenance` (field_id → source: manual | document_id + page + region + extraction confidence)
- `documents` (ingested attachment metadata; blob key reference)

This conceptual schema is already reflected in `VaultAPI`'s types today, even though no SQLCipher-backed implementation exists yet: `ProfileField` (path/value/sensitivity/aliases/verifiedAt/provenance), `HistoryEntry` (category/date-range/fields), `Provenance` (`.manual` or `.document(...)`), `RelationshipEdge`. The canonical catalog of concrete field paths lives in `docs/specs/vault-schema.md`, not in code — see [packages/vault-api.md](../packages/vault-api.md).

**Why relational, not a document store:** conflict detection, history queries, per-field sensitivity, and provenance joins are natural SQL; the schema is stable and small (thousands of rows, not millions). Full-DB encryption via SQLCipher plus column-level ciphertext for values gives defense in depth.

**Semantic index:** embeddings for vault field aliases and form-label history are planned as BLOBs in `forms.db`, searched with in-memory brute-force cosine at query time — a vector database is considered unjustified complexity at this scale.

**Durability:** vault writes are meant to be single-writer-actor, WAL-mode, one transaction per user-visible commit. Document saves follow write-to-temp → validate (re-parse check) → atomic replace → backup version — see [five-product-truths.md](five-product-truths.md) truth 5.
