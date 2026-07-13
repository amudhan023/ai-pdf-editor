# AuditLog

**Purpose:** Append-only, hash-chained local audit log. Entries carry IDs/paths/hashes - the entry type has no value slot; keep it that way.

**Allowed imports:** Foundation (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh AuditLog` (build + tests + boundary lint for this package only).

**Event schema (`AuditEventType`):** `vaultRead`, `vaultWrite`, `ingestionCommitted`, `fillCommitted`, `networkEvent`, `authEvent`.

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- **"No values, ever" is enforced at the type level, not by convention:** `AuditEntry.metadata` is `[AuditMetadataEntry]?`, a closed `AuditMetadataKey` enum paired with a closed `AuditMetadataValue` enum (`.count`, `.flag`, `.durationMs`, `.sha256`). There is no free-string case — `.sha256` carries a `SHA256Hex`, whose only initializer (`SHA256Hex(validating:)`) rejects anything that isn't a 64-char hex digest, so there is no way to construct one from arbitrary text; document/vault content structurally cannot be encoded here. Adding a new key or value case is a deliberate, reviewable change; don't reintroduce a `[String: String]`-shaped escape hatch or a raw `String` payload case.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Bounded size / archival:** `AuditLogStore(directory:maxSegmentBytes:maxLiveSegments:)` moves the oldest live `.seg` files into `directory/archive/` once the live count exceeds `maxLiveSegments` — archived segments are still read by `allEntries`/`entries(matching:)`/`verifyChain`, so archival bounds the hot working set without losing history.

**Read API:** `entries(matching: AuditEntryFilter)` filters by event type(s), ticket ID, field-path prefix, and/or date range — this is the path the Privacy Dashboard (P3-03) is expected to drive; don't add a second query surface.

**Event bus subscription:** `AuditLogStore.subscribe<S: AsyncSequence>(to:) where S.Element: AuditableEvent` durably appends each event in order before advancing. Deliberately decoupled from `Platform.DomainEventBus` (no dependency either direction — see `Packages/Platform/CLAUDE.md`): a new cross-package dependency needs its own ADR (CLAUDE.md §3.7), so the adapter conforming a bus's concrete event type to `AuditableEvent` belongs in whichever package first needs both wired together, not here.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
