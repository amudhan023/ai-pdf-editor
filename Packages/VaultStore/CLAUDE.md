# VaultStore

**Purpose:** Vault.xpc service implementation: SQLCipher store (`SQLCipherVaultStore`), Secure Enclave–wrapped key hierarchy (`KeyHierarchy/`), mlock'd lock state (`Lock/`), encrypted attachments (`Attachments/`), and rolling encrypted backups (`Backup/`). Every privileged call requires a verified `PolicyTicket`. Decrypted values are `SecureBytes` only. Sibling `Services/VaultService` is the thin XPC executable skeleton over this package (real `.xpc` bundle packaging is P0-07's job).

**Allowed imports:** Foundation, VaultAPI, PolicyKit, Platform, Security, CryptoKit, GRDB (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh VaultStore` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16) — enforced by `NoPlaintextLoggingTests`' source-grep guard.
- Real callers go through `TicketVerifyingVaultClient` (adds HMAC verification + replay rejection), never the bare `SQLCipherVaultStore` — the bare store only enforces the structural ticket contract `VaultConformanceSuite` checks (same split rationale as that suite's own doc comment).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
