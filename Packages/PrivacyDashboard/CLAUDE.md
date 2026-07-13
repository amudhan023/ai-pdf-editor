# PrivacyDashboard

**Purpose:** Trust surface: stored-data summary, audit timeline, network activity disclosure and toggles.

**Allowed imports:** Foundation, AuditLog, VaultAPI (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh PrivacyDashboard` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Contents (P3-03):** `StorageSummaryService` (per-person field-presence counts via `VaultClient.compareRead` — counts only, never values), `ActivityTimelineViewModel` (filterable read over `AuditLogStore.entries` + chain-verification status), `NetworkActivityViewModel`/`NetworkConnectionSettingsStore` (toggle state for the enumerated `NetworkConnectionKind`s + last-contact from `.networkEvent` entries), `VaultExportService` (MVP JSON export) and `SecureEraseViewModel` (typed-confirmation crypto-shred state machine), `VaultFieldCatalog` (mirrors `docs/specs/vault-schema.md`'s leaf paths, grouped by section).

**Known gaps:**
- This package has no way to enumerate `Person`s itself (no such `VaultClient` method) — callers (the composition root) supply the person list and mint per-person `PolicyTicket`s.
- Toggling a `NetworkConnectionKind` off here only persists the *preference*; this package makes no network calls itself (nor could it — no network entitlement), so actual enforcement lives at whatever future call site dials update-check/license-validation. `NetworkActivityViewModelTests` proves the settings contract with a fake dialer, not a real one (none exists yet).

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
