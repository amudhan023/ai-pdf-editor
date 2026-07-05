---
type: package
title: VaultAPI
description: Vault domain model — profiles, field paths, sensitivity tiers, provenance, history, PolicyTicket shape, and the VaultClient protocol. Frozen seam v1 (ADR-007).
tags: [package, api-contract, vault, frozen-seam, policy-ticket]
implementation_status: implemented
---

# VaultAPI

**Purpose:** the vault's domain model and client protocol — profiles, field paths, sensitivity tiers, provenance, history lists, the `PolicyTicket` type, and `VaultClient` + `FakeVaultClient`. **Frozen seam v1 (ADR-007):** changes require a superseding ADR + `[INTEGRATION]` PR with human review.

## `VaultClient` protocol

Every method except `lockState()` requires a `PolicyTicket` — no bypass path, including in other packages' tests (use `FakeVaultClient`, never a ticket-free shortcut). Method groups: person CRUD (`createPerson`/`person`/`deletePerson`), field CRUD (`writeField`/`readFields`/`deleteField`), `compareRead` (conflict-detection: reveals presence/sensitivity/verifiedAt/fingerprint, never the raw value), history CRUD, relationship-edge CRUD, and `cryptoShred` (irreversible destruction of a person's data — commits to the observable effect at the protocol level, key destruction is `VaultStore`'s job).

## Key types

- `PersonID`/`PersonKind`/`Person` — a profile is a person or organization.
- `FieldSection`/`FieldPath` — dot-separated, lowercase, validated paths (`identity.passport.number`). `FieldPath(validating:)` throws on an unknown section rather than silently accepting one — the type-level enforcement of "never invent paths ad hoc." `FieldPath.custom(_:)` is the sanctioned extension mechanism. The concrete catalog of paths lives in `docs/specs/vault-schema.md`, not in this type.
- `FieldValueKind`/`FieldValue` — `.string(SecureBytes)`/`.date(Date)`/`.number(Double)`/`.enumeration(String)`/`.list([FieldValue])`. The enum case *is* the type (no separate stored `type` field to desync). `.string` carries `SecureBytes`, never `String`. `stableFingerprint()` (dependency-free FNV-1a) backs `compareRead` — equality-only, not cryptographic.
- `SecureBytes` — wire/DTO shape enforcing the `exposeAsPlaintext()` seam; redacted `description`/`debugDescription`. Not a memory-hardening primitive (no `mlock`/zero-on-deallocate) — see [../architecture/security-model.md](../architecture/security-model.md).
- `SensitivityTier` — `.standard`/`.sensitive`.
- `Provenance` — `.manual` or `.document(documentID:page:region:confidence:)`. Every `ProfileField` carries one.
- `PersonID`-scoped `ProfileField` (path/value/sensitivity/aliases/verifiedAt/provenance), `HistoryEntry` (category/date-range/fields — first-class, not JSON, for gap-detection queries), `RelationshipEdge` (directed, not auto-mirrored).
- `VaultOperation`/`PolicyTicket` — operation-scoped (read/write/compareRead/cryptoShred), person-scoped, path-scoped (`scopedPaths` empty = person-level), time-boxed. `covers(_:)`/`isTemporallyValid(at:)` are the structural checks any `VaultClient` must enforce regardless of signature validity.
- `VaultError` — typed taxonomy including `.vaultLocked` (modeled as a normal, handleable state, not an exceptional error).
- `FieldSummary` — the `compareRead` result shape.

## Allowed imports

Foundation only.

## Invariants

- Every `VaultClient` operation but `lockState()` requires a `PolicyTicket`.
- `FieldValue.string` never carries a bare `String`.
- No `ExpressibleByStringLiteral` on `FieldPath` — every path must go through the throwing `init(validating:)`.

Consumed by (all currently stubs): `AutofillSession`, `IngestionSession`, `AutofillEngine`, `IngestionPipeline`, `VaultManagerUI`, `PrivacyDashboard`, `VaultStore` (the real implementation, once built). Ticket production/verification is [policy-kit.md](policy-kit.md)'s job.
