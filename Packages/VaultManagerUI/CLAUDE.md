# VaultManagerUI

**Purpose:** Vault window: profile management, field editing, sensitivity masking, unlock UX. Talks to the vault only through VaultAPI client protocols.

**Allowed imports:** Foundation, VaultAPI, PolicyKit, SwiftUI, AppKit, os, OSLog (see `Scripts/import-allowlist.txt` — the enforced source of truth). No CryptoKit: real `PolicyTicket` signing needs a `SymmetricKey` only Platform/Keychain may hold. Tests may also import XCTest.

**Shape (P1-11):** `Support/` has the two capability seams this package can't fulfill itself — `TicketIssuing` (real `PolicyRules.decide`, fake-signed ticket; production signing is a composition-root `[INTEGRATION]` follow-up) and `VaultUnlocking`/`RecoveryCodeProviding` (real unlock/recovery-code material lives in `VaultStore`, unreachable here). View models (`ProfileListViewModel`, `ProfileDetailViewModel`, `VaultUnlockViewModel`) are `@MainActor`, SwiftUI-free, and unit-testable against `FakeVaultClient`; `Views/` wires them to SwiftUI.

**Verify:** `Scripts/verify.sh VaultManagerUI` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content — `RevealAuditLog` logs field *section* + sensitivity only, never the path's leaf segments or value (CLAUDE.md §16).
- Revealed values never persist outside a `DisplayField.revealedValue` the user explicitly triggered; masking-back (`mask(_:)`) must be called on navigation-away/lock.
- Pasteboard copies of revealed values go through `TransientPasteboard` only (org.nspasteboard convention + changeCount-gated auto-clear) — never `NSPasteboard.general.setString` directly (CLAUDE.md §7.4).
- `VaultClient` has no "list all persons"/"list all fields" operation (frozen seam) — `persons`/`fields` dictionaries reflect only what this session created or explicitly loaded, not a live query. A real launch-time index needs a mechanism from outside this package.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone. No `.xcodeproj` exists in this repo, so no true XCUITest is possible here either (same constraint as `App/`) — covered by view-model tests instead.
