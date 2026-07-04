# Vault Field-Path Catalog

**Owner of this fact:** this document. `VaultAPI`'s `FieldPath`/`FieldSection` types (`Packages/VaultAPI/Sources/VaultAPI/FieldPath.swift`) enforce the *shape* every path must have; this document is the catalog of *which paths exist*. CLAUDE.md §5: "Vault field paths: dot-separated lowercase — catalog in docs/specs/vault-schema.md; never invent paths ad hoc." Adding a field means adding a row here in the same PR, not inventing a path string at a call site.

Corresponds to PRD FR-2.1's core sections and ARCHITECTURE.md §8.2's conceptual schema (`persons` / `sections -> fields` / `history_entries` / `provenance`).

## Path shape

- Dot-separated, lowercase segments; each segment is `[a-z0-9_]+`.
- The first segment must be one of the `FieldSection` cases below — `FieldPath(validating:)` rejects anything else, so a typo'd or invented section fails to parse rather than silently creating a new one.
- A bare section name (e.g. `identity`) is a valid `FieldPath` too — it's not a leaf field, but `PolicyTicket.scopedPaths` uses it to grant a whole section without enumerating every leaf (`FieldPath.isPrefix(of:)`).

## Custom-field extension mechanism (FR-2.1: "Custom fields/sections")

`FieldPath.custom(_:)` builds a path under the reserved `custom` section: `FieldPath.custom(["notes"])` -> `custom.notes`; `FieldPath.custom(["boat", "hull_id"])` -> `custom.boat.hull_id`. This is the *only* sanctioned way to add a field the catalog below doesn't enumerate — never validate a hand-built string against a made-up top-level section. Custom paths still go through the same charset validation as catalog paths.

## Catalog

Each row's **Type** is a `FieldValueKind`; **Sensitivity** is the *typical* `SensitivityTier` for that path (still a per-field, per-user setting at write time — this is guidance for callers picking a default, not something `FieldPath` enforces).

### `identity`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `identity.legal_name.first` | string | standard | |
| `identity.legal_name.middle` | string | standard | |
| `identity.legal_name.last` | string | standard | |
| `identity.preferred_name` | string | standard | |
| `identity.date_of_birth` | date | sensitive | |
| `identity.place_of_birth` | string | standard | |
| `identity.nationality` | enum | standard | options catalog TBD (ISO 3166 country codes) |
| `identity.ssn` | string | sensitive | FR-2.5 names this explicitly |
| `identity.passport.number` | string | sensitive | FR-2.5 names this explicitly |
| `identity.passport.issuing_country` | enum | standard | |
| `identity.passport.expiration_date` | date | standard | feeds FR-2.8 expiry notifications |
| `identity.drivers_license.number` | string | sensitive | |
| `identity.drivers_license.state` | enum | standard | |
| `identity.drivers_license.expiration_date` | date | standard | |

### `contact`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `contact.address.line1` | string | standard | current address; history lives in `HistoryEntry(category: .address)`, not here |
| `contact.address.line2` | string | standard | |
| `contact.address.city` | string | standard | |
| `contact.address.state` | string | standard | |
| `contact.address.postal_code` | string | standard | |
| `contact.address.country` | enum | standard | |
| `contact.phone.mobile` | string | standard | |
| `contact.phone.home` | string | standard | |
| `contact.phone.work` | string | standard | |
| `contact.email.primary` | string | standard | |
| `contact.email.secondary` | string | standard | |

### `employment`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `employment.current.employer_name` | string | standard | current row; history via `HistoryEntry(category: .employer)` |
| `employment.current.title` | string | standard | |
| `employment.current.start_date` | date | standard | |
| `employment.income.annual` | number | sensitive | |

### `education`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `education.highest.institution_name` | string | standard | full history via `HistoryEntry(category: .education)` |
| `education.highest.degree` | string | standard | |
| `education.highest.field_of_study` | string | standard | |
| `education.highest.graduation_date` | date | standard | |

### `family`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `family.emergency_contact.name` | string | standard | the relationship itself is a `RelationshipEdge(kind: .emergencyContact)`, not a field path |
| `family.emergency_contact.phone` | string | standard | |

### `financial`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `financial.bank.account_last4` | string | sensitive | never store a full account number under this path — last 4 only, matching what forms typically ask for |
| `financial.bank.routing_number` | string | sensitive | |
| `financial.business.ein` | string | sensitive | organization-kind `Person` profiles use this |

### `health` (optional per FR-2.1)

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `health.insurance.provider` | string | sensitive | |
| `health.insurance.policy_number` | string | sensitive | |
| `health.physician.name` | string | standard | |
| `health.allergies` | list | sensitive | list of `string` `FieldValue`s |

### `licenses`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `licenses.professional.name` | string | standard | e.g. "PE", "RN" |
| `licenses.professional.number` | string | sensitive | |
| `licenses.professional.expiration_date` | date | standard | feeds FR-2.8 |

### `travel`

| Path | Type | Sensitivity | Notes |
|---|---|---|---|
| `travel.frequent_flyer.airline` | string | standard | |
| `travel.frequent_flyer.number` | string | sensitive | |

Trip-level travel history (dates + destinations) is a `HistoryEntry(category: .travel)`, not a flat path — it needs date ranges, which flat fields don't carry.

### `custom`

No catalog rows by definition — see "Custom-field extension mechanism" above.

## History-list categories (`HistoryCategory`)

First-class per ARCHITECTURE.md §8.2 rather than folded into flat field paths, because gap-detection queries need date ranges: `address`, `employer`, `education`, `travel`. Each `HistoryEntry` carries its own `DateRange` (`end == nil` means ongoing) and a set of `HistoryFieldEntry` (path + value) scoped to that one entry — e.g. an `employer` entry's fields might be `employment.current.employer_name`/`employment.current.title` values as they were *during that job*, not the profile's current values.

## Relationship kinds (`RelationshipKind`)

`spouse`, `child`, `parent`, `sibling`, `emergencyContact`, plus `.other(String)` for anything the fixed set doesn't name (PRD FR-2.3's named set plus an escape hatch, same spirit as `FieldPath.custom`). Edges are directed and not auto-mirrored; query by either endpoint via `VaultClient.relationships(for:)`.

## Provenance (`Provenance`)

`.manual` or `.document(documentID:page:region:confidence:)` — every `ProfileField` carries one (CLAUDE.md product truth #3: "every value is traceable to its source").

## `PolicyTicket` operations (`VaultOperation`)

`read` (full disclosure), `write` (create/update/delete, collapsed to one case — PolicyKit mints a ticket per user-visible decision, not per SQL verb), `compareRead` (conflict-detection summary only — see `FieldSummary`, never the raw value), `cryptoShred` (FR-2.6's one-click secure erase).
