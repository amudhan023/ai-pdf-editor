**Owner:** claude-code (session P0-09) · **Branch:** task/P0-09-vault-api-package · **Claimed:** 094af94

# P0-09 — VaultAPI Package: Schema Types & PolicyTicket (Freeze Point)

**Epic:** E8 · **Primary package:** `Packages/VaultAPI` · **Complexity:** M · **Priority:** Critical

## Goal
Define the vault domain model (persons, sections, field paths, sensitivity tiers, provenance, history lists, relationships) and the `PolicyTicket` capability type — the contract for Vault.xpc, autofill, and ingestion.

## Background
ARCHITECTURE.md §3.2 (VaultModel), §8.2 (schema), §3.3 (PolicyTicket handshake). PRD FR-2.1–2.5. M0 freeze point: Track B and Track C both build against these types.

## Requirements
- Typed field-path system (`identity.passport.number`), field value types (string/date/number/enum/list), sensitivity tiers, alias lists, verified-at metadata.
- Person/organization profiles + typed relationship edges; history-list entry types with date ranges.
- Provenance model (manual | document+page+region+confidence).
- `PolicyTicket`: operation-scoped, time-boxed, field-path-scoped grant token (opaque signature payload; signing lives in PolicyKit).
- Client protocol for vault operations (CRUD, compare-read, crypto-shred) — implementation-free; `FakeVaultClient` included.

## Dependencies
- P0-01.

## Files Likely Affected
- `Packages/VaultAPI/Sources/**`, `Tests/**`.

## Acceptance Criteria
- Canonical field-path catalog covers PRD FR-2.1 sections incl. custom-field extension mechanism.
- `FakeVaultClient` passes shared conformance suite (reused against real Vault.xpc later).

## Definition of Done
- Global DoD, plus: freeze recorded in ADR-007-vaultapi-v1.md.

## Testing Requirements
- Path parsing/validation tests; Codable round-trips; conformance suite.

## Documentation Updates
- Package `CLAUDE.md`; field-path catalog doc in docs/specs/vault-schema.md.

---
## Journal

**Context read (Step 1):** root `CLAUDE.md`; this task file; `Packages/VaultAPI/CLAUDE.md` + its (placeholder) `Sources`/`Tests`; ARCHITECTURE.md §3.2 (VaultModel row), §3.3 (PolicyTicket handshake), §8.2 (vault schema); PRD FR-2.1–2.8; `Scripts/import-allowlist.txt` (confirmed `VaultAPI:` is Foundation-only, no entry needed); the unmerged `task/P0-04-pdf-engine-api` branch's `Packages/PDFEngineAPI/` + `docs/adr/ADR-006-pdfengineapi-v1.md` as the structural precedent for this shape of task (protocols + value types + `Fake*` + conformance suite + ADR).

**Plan (Step 2):** typed `FieldPath`/`FieldSection` (validated, Foundation-only, `custom` escape hatch) → `FieldValueKind`/`FieldValue` (string/date/number/enum/list) → `SensitivityTier`, `Provenance`/`ProvenanceRegion` → `PersonID`/`Person`, `RelationshipKind`/`RelationshipEdge` → `DateRange`/`HistoryCategory`/`HistoryFieldEntry`/`HistoryEntry` → `ProfileField` → `VaultOperation`/`PolicyTicket` → `VaultError` → `FieldSummary` → `VaultClient` protocol → `FakeVaultClient` → `VaultConformanceSuite`. Tests: path parsing/validation, Codable round-trips (one file each, matching every DTO), `FakeVaultClient` behavior (locked vault, history/relationship CRUD, cascading delete), conformance-suite-passes. No frozen seam other than this package itself needed changing; no new dependency; no entitlement — proceeded without escalating on process grounds.

**Mid-implementation finding, fixed in-package (not noted-and-moved-past, per CLAUDE.md §7.9):** the task's own Requirements list specifies "field value types (string/...)" without naming `SecureBytes`, but Constitution Art. 11 (immutable) and CLAUDE.md §5/§7.3 require decrypted vault values to travel as `SecureBytes`, never bridged to `String` except at the final UI/engine write. Shipping `FieldValue.string(String)` on a frozen seam would have been exactly the kind of defect §7.9 says to fix immediately, not note and move past — and retrofitting it after Track B/C build against this ADR would need a breaking, superseding ADR. Added `SecureBytes` (Foundation-only wire/DTO shape: forces the `exposeAsPlaintext()` seam, redacts `description`/`debugDescription`; explicitly does **not** claim `mlock`/zeroize-on-deinit memory hardening — that's `VaultStore`/`Platform`'s job per P1-08) and made `FieldValue.string` carry it. Scope and reasoning (including why `.number`/`.date`/`.enumeration` and `Person.displayName` were *not* changed) recorded in full in ADR-007's "SecureBytes decision" section for reviewer override if the line was drawn wrong.

**Deviations from the literal task text, all recorded in ADR-007:**
- `VaultOperation` collapses full CRUD to four cases (`read`/`write`/`compareRead`/`cryptoShred`) rather than one per SQL verb — PolicyKit mints a ticket per user-visible decision, not per verb.
- `VaultClient` requires a `PolicyTicket` on every operation including person-level reads (`person(_:)`, `relationships(for:)`), stricter than the single field-read example ARCHITECTURE.md §3.3 quotes, per CLAUDE.md §3.3's absolute "no bypass path" wording.
- Vault-locked behavior is exercised only in `FakeVaultClient`'s own behavior tests, not the shared conformance suite — the protocol has no generic lock-setter (real unlock is biometric, out of this package's reach), so the suite can't induce it against an arbitrary implementation.

**Verification (Step 4):** `Scripts/verify.sh VaultAPI` green (build + `swift test` — full Xcode present, 31 tests, 0 failures — + `check-boundaries.sh VaultAPI` clean). `swiftlint lint --config .swiftlint.yml Packages/VaultAPI` → 0 violations (one real hit fixed: `ProvenanceRegion`'s `x`/`y` renamed `originX`/`originY`, `RelationshipEdge`'s `to` given an internal `toPersonID` name behind a `to:` external label, test-local `a`/`b` renamed to descriptive names — root `.swiftlint.yml`'s `identifier_name` rule flags 2-char identifiers by default on `main`; the x/y/id exception exists only on the separate, unmerged `task/P0-04-pdf-engine-api` branch, not something this task's scope permits adding). `Scripts/check-boundaries.sh --self-test` still passes (planted violation still detected, unaffected by this diff).

**Harden pass (Step 5):** re-read the full diff; no dead code/debug scaffolding; every thrown error path has a covering test (ticket wrong-operation/wrong-scope/expired, locked vault, unknown person, deleted field, post-shred read); no abstraction serving a single call site.

**Security/privacy self-audit:** this package touches vault *shapes*, not vault *values* at rest — it defines the DTOs `Vault.xpc` will use, with no storage/crypto code (`ProfileField.value` uses `SecureBytes` for its freeform-text case per the finding above). No network APIs (Foundation-only). No logging anywhere in the package. Every `VaultClient` method but `lockState()` requires a `PolicyTicket`, structurally checked in `FakeVaultClient` (operation, person, path-scope via `FieldPath.isPrefix(of:)`, temporal validity) — there is no ticket-free path to call it.

**Acceptance criteria status:**
- "Canonical field-path catalog covers PRD FR-2.1 sections incl. custom-field extension mechanism": met — `docs/specs/vault-schema.md` has a table per section (identity/contact/employment/education/family/financial/health/licenses/travel) plus the `custom` escape hatch via `FieldPath.custom(_:)`, all validated by `FieldPathTests`.
- "`FakeVaultClient` passes shared conformance suite (reused against real Vault.xpc later)": met — `FakeVaultClientConformanceTests` runs `VaultConformanceSuite`'s four checks (profile+field CRUD, compare-read, ticket discipline, crypto-shred) against `FakeVaultClient`; the suite is shipped in the library (not `Tests/`) so `VaultStore` (P1-08) can import and reuse it unmodified.

**Next agent / human:** this is an API-package PR (frozen seam) — per CLAUDE.md §21/AGENT_LOOP.md Step 8a it needs human review regardless of CI status; not self-merging. If CI surfaces something unexpected, read the actual log before re-guessing (cap: 5 fix-and-recheck attempts, AGENT_LOOP.md Step 8a). On approval: rebase, merge, move this file to `done/`.

**PR #17 opened; CI run investigated (not a code issue — filing here instead of guessing/retrying):** the full matrix triggered as expected (this PR touches `Packages/*API/`). `detect-changes` and `repo-checks` (SwiftLint, PII scan, codegen-drift) passed. 12 of 17 `verify` matrix jobs failed, but every one of them — including packages this PR never touches, e.g. `PDFEngineAPI`, `FormKnowledge`, `DocEngineHost` — shows the identical annotation: *"The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings."* This is a GitHub Actions account billing/spending-limit block, not a build/test/lint failure, and it hit jobs essentially at random within the matrix (some, like `AutofillSession`/`DocumentSession`/`InferenceHost`/`InferenceAPI`/`Platform`/`PolicyKit`, started before the account got blocked and passed). Per AGENT_LOOP.md §9's escalation table ("anything requiring spending money... -> request with exact need"), this needs a human to resolve billing in GitHub settings, not a code fix or retry — did not burn fix-loop attempts on it. Re-run the workflow (`gh run rerun 28714400814` or via the PR's Checks tab) once billing is resolved; `VaultAPI`'s own job failed only because of this same block, not a real test/lint failure (see local `Scripts/verify.sh VaultAPI` → `OK`, 31/31 tests, above).
