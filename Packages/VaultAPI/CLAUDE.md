# VaultAPI

**Purpose:** Vault domain model: profiles, field paths, sensitivity tiers, provenance, history lists, PolicyTicket type, client protocols + FakeVaultClient. **FROZEN SEAM v1 (ADR-007): changes require a superseding ADR + `[INTEGRATION]` PR with human review.**

**Contents:** `FieldSection`/`FieldPath` (validated paths; catalog lives in `docs/specs/vault-schema.md`, not here), `FieldValueKind`/`FieldValue` (string/date/number/enum/list), `SecureBytes` (see Gotchas), `SensitivityTier`, `Provenance`/`ProvenanceRegion`, `PersonID`/`PersonKind`/`Person`, `RelationshipKind`/`RelationshipEdge`, `DateRange`/`HistoryCategory`/`HistoryFieldEntry`/`HistoryEntry`, `ProfileField`, `VaultOperation`/`PolicyTicket`, `VaultError`, `FieldSummary`, `VaultClient` protocol, `VaultLockState`. `FakeVaultClient` (in-memory actor, all protocol methods) and `VaultConformanceSuite` (protocol-conformance checks any real client must also pass) are shipped in the library, not `Tests/`, so consumer packages can build/test against them.

**Allowed imports:** Foundation only (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh VaultAPI` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Every `VaultClient` operation but `lockState()` requires a `PolicyTicket`; there is no bypass path, including in other packages' tests (use `FakeVaultClient`, not a ticket-free shortcut) (CLAUDE.md §3.3).
- `FieldValue.string` carries `SecureBytes`, never `String` (Constitution Art. 11; CLAUDE.md §7.3) — see Gotchas for what that type does and does not guarantee.
- Never invent a field path ad hoc: `FieldPath(validating:)` only accepts a known `FieldSection`; extend via `FieldPath.custom(_:)`, and add real paths to `docs/specs/vault-schema.md` in the same PR.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:**
- `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
- `SecureBytes` is a wire/DTO shape (forces the `exposeAsPlaintext()` seam, redacts `description`), not a memory-hardening primitive — no `deinit`-driven zeroization or `mlock`. The real hardened master-key handling is `VaultStore`/`Platform`'s job (P1-08); don't read more security guarantee into this type than it documents (ADR-007).
- `FieldValue.stableFingerprint()` (used by `compareRead`) is a dependency-free FNV-1a hash for equality comparison only — not cryptographic, not for anything collision-resistance-sensitive.
- No `ExpressibleByStringLiteral` on `FieldPath` by design: every path must go through `init(validating:)`, which can throw — call sites propagate the parse error rather than reaching for `try!`.
