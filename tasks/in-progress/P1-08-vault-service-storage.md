**Owner:** claude-code · **Branch:** task/P1-08-vault-service-storage · **Claimed:** 6046e01dfab47b97d5a28c2559a4e3fdca91fc4f

# P1-08 — Vault.xpc: SQLCipher Store & Key Hierarchy

**Epic:** E8 · **Primary package:** `Packages/VaultStore` + `Services/VaultService` · **Complexity:** L · **Priority:** Critical

## Goal
The vault service process: SQLCipher database implementing the VaultAPI schema, Secure Enclave–wrapped key hierarchy, and crypto-shred — per ARCHITECTURE.md §6.2/§8.

## Background
This is the most security-sensitive task in the project. Key hierarchy: SE key → wrapped master key (Keychain + recovery-code copy) → DB/attachment/backup keys. Single-writer actor, WAL, transactional commits.

## Requirements
- GRDB + SQLCipher schema per ARCHITECTURE.md §8.2 (persons, sections/fields, history_entries, provenance, documents) with migration framework from v1.
- Key generation, SE wrapping, Keychain storage, recovery-code wrap (code generation + one-time display handled later in UI); master key held only in Vault.xpc, `mlock`ed, zeroized on lock.
- Crypto-shred: destroy wrapped copies → verify DB unreadable.
- XPC surface (over P0-05 transport) implementing VaultAPI client protocol; **every privileged call requires a verified PolicyTicket** (verification helper from PolicyKit).
- Encrypted attachment store (per-file AES-256-GCM) and rolling encrypted local backups.

## Dependencies
- P0-05, P0-09, P0-10.

## Files Likely Affected
- `Packages/VaultStore/Sources/**`; `Services/VaultService/**`.

## Acceptance Criteria
- VaultAPI conformance suite (from P0-09) passes against the real service.
- DB file is unreadable ciphertext without unlock; ticket-less calls are rejected; crypto-shred verified by attempted-open test.
- No plaintext value ever appears in logs/temp files (audited by test hooks).

## Definition of Done
- Global DoD, plus: threat-model checklist (ARCHITECTURE.md §6.1 rows) self-review recorded in PR.

## Testing Requirements
- Conformance + migration tests; key lifecycle tests (wrap/unwrap/zeroize); crash-mid-transaction recovery test; backup/restore round-trip.

## Documentation Updates
- `Packages/VaultStore/CLAUDE.md` security invariants (SecureBytes rules, no-String bridging).

## Journal

### Orient
Read: root CLAUDE.md, this task file, `Packages/VaultStore/CLAUDE.md`, ARCHITECTURE.md §6.2 (key hierarchy) + §8.2 (vault schema), `VaultAPI` full source (VaultClient, FakeVaultClient, ConformanceSuite, PolicyTicket, FieldPath, FieldValue, SecureBytes, Person, ProfileField, HistoryEntry, RelationshipEdge, FieldSummary, Provenance, SensitivityTier, VaultError), `PolicyKit` full source (PolicyRules, TicketMinter, TicketVerifier, TicketClaims, ReplayGuard), Scripts/verify.sh, Scripts/check-boundaries.sh, Scripts/import-allowlist.txt.

Found pre-existing untracked scaffolding from an earlier session on this same branch (never committed): `ThirdParty/GRDB` (GRDB vendored + hand-written Package.swift wiring GRDBSQLCipher per GRDB's documented SPM recipe, pinned to `SQLCipher.swift` 4.16.0) and `Scripts/vendor-grdb.sh`. Verified `swift build` inside `ThirdParty/GRDB` succeeds standalone. Adopting this as this task's dependency vendoring rather than redoing it.

**Empirically verified in this sandbox** (affects design):
- Keychain (`SecItemAdd`/`SecItemCopyMatching`, generic password class) works fine here.
- Secure Enclave key generation (`SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`) fails here with `errSecInteractionNotAllowed` (-25308) — no interactive Security Server session in this headless sandbox. This is expected outside real hardware/an interactive session, same class of environment gap as E-002 (XCTest needs Xcode.app). Real-device verification of the SE wrap/unwrap path is out of reach in this environment.

### Plan
1. **Dependency wiring**: `VaultStore/Package.swift` depends on `../../ThirdParty/GRDB`; `Scripts/import-allowlist.txt` VaultStore line gains `GRDB CryptoKit`.
2. **Key hierarchy** (`Sources/VaultStore/KeyHierarchy/`): `KeyWrappingProvider` protocol (seam over the SE dependency, same "protocol + fake" pattern as `VaultClient`/`FakeVaultClient` — necessary because SE can't run in this sandbox); `SecureEnclaveKeyBox` (real impl, `SecKeyCreateRandomKey`/`SecKeyCreateEncryptedData`/`SecKeyCreateDecryptedData`, ECIES cofactor X963 SHA256 AES-GCM); `KeychainStore` (generic-password wrapped-blob get/set/delete); `RecoveryCode` (generation + HKDF-derived wrapping key, AES-GCM wrap of the master key copy — a second, SE-independent wrap so it survives biometry reset per ARCHITECTURE.md §6.2); `MasterKeyManager` (provision/unlock/unlockWithRecoveryCode/shredMasterKey — the whole-vault crypto-shred); `DerivedKeys` (HKDF-SHA256, domain-separated info strings for DB/attachment-root/backup keys).
3. **Lock state** (`Sources/VaultStore/Lock/`): `LockedBytes` (mlock'ed/zeroized-on-deinit raw buffer — verified `mlock`/`munlock`/`memset_s` are callable with only `import Foundation`, no `Darwin` import needed, so boundary lint stays clean), `VaultLockController` (actor orchestrating MasterKeyManager + holding derived keys in `LockedBytes` while unlocked, zeroizes on lock).
4. **Schema** (`Sources/VaultStore/Schema/`): GRDB `DatabaseMigrator` v1 (person/profileField/historyEntry/historyFieldEntry/relationshipEdge/document tables, FK cascade), Codable Record structs, JSON-blob encoding of `FieldValue`/`Provenance`/aliases (already `Codable` in VaultAPI) — full-DB SQLCipher encryption is the ciphertext-at-rest guarantee; column-level ciphertext is explicitly a documented future upgrade in ARCHITECTURE.md §8.2, out of scope here.
5. **`SQLCipherVaultStore`**: single actor implementing `VaultClient` end-to-end, mirroring `FakeVaultClient`'s exact structural ticket-check semantics (operation/scope/expiry — same helper shape) so it's a drop-in for `VaultConformanceSuite`; owns unlock()/lock() (opens/closes a GRDB `DatabasePool` keyed via raw-hex `PRAGMA key`, `PRAGMA foreign_keys=ON`, `PRAGMA secure_delete=ON`, migrates on unlock); `cryptoShred(person:)` is a hard cascade-delete under `secure_delete` (per-person; whole-vault shred is `MasterKeyManager.shredMasterKey()`, a separate, stronger operation — the `VaultClient` protocol only commits to the per-person observable effect per its own doc comment).
6. **`TicketVerifyingVaultClient`**: generic decorator adding real HMAC signature verification (`PolicyKit.TicketVerifier`) + replay rejection (`PolicyKit.ReplayGuard`) in front of any `VaultClient`. Kept separate from `SQLCipherVaultStore` deliberately: `VaultConformanceSuite` mints tickets with a dummy empty `signature` by its own documented design ("signature verification is PolicyKit's concern, out of scope for this protocol layer") — so the suite must run against the undecorated store, while the decorator gets its own dedicated signature/replay tests. This composition is the intended seam, not a shortcut around §3.3 (structural ticket checks are still enforced with no bypass at the store layer itself, same as `FakeVaultClient`).
7. **`Attachments/AttachmentStore.swift`**: per-file AES-256-GCM, file key HKDF-derived from the attachments-root key per attachment ID.
8. **`Backup/BackupManager.swift`**: rolling encrypted snapshots (AES-256-GCM over the already-SQLCipher-encrypted DB file, backup-key domain) + restore.
9. **`Services/VaultService`**: thin XPC skeleton package, identical pattern to `Services/DocEngineService`/`Services/InferenceService` (P0-05/P1-12 precedent) — proves `Platform` XPC transport links against `VaultStore`; real `.xpc` bundle packaging is P0-07's job, out of scope here.

**Test strategy**: conformance (VaultAPI's shared suite against `SQLCipherVaultStore`), migration, key lifecycle (against `MockKeyWrappingProvider`/`MockKeychainStore` test doubles, since real SE/Keychain-in-CI isn't reachable here for the SE leg specifically — Keychain itself works, SE doesn't), crypto-shred attempted-open test, ticket-verifying-decorator negative tests (tampered signature, replay, expired), crash-mid-transaction (rollback + reopen-after-close durability), backup/restore round-trip, attachment round-trip + tamper detection, and a source-grep test guarding against `print(`/plaintext logging in this package.

**Risk flagged, not escalated**: `SecureEnclaveKeyBox`'s real code path cannot be exercised end-to-end in this sandbox (confirmed above). It's implemented per Apple's documented API and reviewed for correctness, but its integration test coverage is necessarily against the `KeyWrappingProvider` protocol seam (mock), not real hardware. Noting this in the PR rather than treating it as a blocker — same category as E-002.

### Implement / Verify

Wrote the full `Tests/VaultStoreTests` suite the earlier session's plan had scoped but not yet built: `SQLCipherVaultStoreConformanceTests` (all four `VaultConformanceSuite` checks against the real store), `VaultLockAndCipherTests` (DB file is non-SQLite ciphertext at rest, locked-vault calls rejected, reopen-after-close durability), `MasterKeyLifecycleTests` + `VaultLockControllerTests` (provision/unlock/recovery-unlock/wrong-code/shred against `MockKeyWrappingProvider`, derived-key-domain distinctness, post-lock zeroization surfacing as `vaultLocked`), `TicketVerifyingVaultClientTests` (tampered signature, replay, expired, wrong signing key, valid pass-through — all via real `PolicyKit.TicketMinter`/`TicketVerifier`), `AttachmentStoreTests` and `BackupManagerTests` (round-trip, ciphertext-on-disk, tamper detection, retention pruning), `MigrationAndTransactionTests` (migrator idempotent across reopen, failed write doesn't partially commit), and `NoPlaintextLoggingTests` (source-grep guard). Also built the `Services/VaultService` XPC skeleton (identical thin-main pattern to `DocEngineService`/`InferenceService`) with its own integration test.

**Surprise**: this sandbox now has full Xcode (`xcode-select -p` → `/Applications/Xcode.app/...`, confirmed via `xcodebuild -version`), so `swift test` actually runs here — E-002's CLT-only assumption no longer holds for *this* environment (P0-01/P0-02 already unblocked via CI having Xcode regardless, so this doesn't change any decision, just confirms tests locally). All 30 `VaultStore` tests and 1 `VaultService` test pass locally, not just hypothetically.

**Gate fixes**: `swiftlint lint` found one blocking violation (`force_try` in the test factory's `try!` directory setup) — fixed by making `VaultStoreTestFactory.makeHarness` throwing. Remaining `inclusive_language`/`identifier_name` warnings are pre-existing (not introduced this session, not error-severity, don't block `repo-checks`).

**Concurrency note**: found the branch already carrying an unrelated, already-merged supervisor tooling PR (#38, `claude_supervisor.py` token-window-probe fix) squashed into `origin/main` under a different SHA than this branch's copy of the same commit. Rebased this branch onto `origin/main` (dropped the now-redundant duplicate commit) before adding this work, so this PR's diff is P1-08-only.

**CI wiring**: added a `services` job step for `Services/VaultService` (mirroring `DocEngineService`). Also discovered, while doing so, that `Services/InferenceService` (P1-12, already merged) was never added to this job despite its own PR's job header comment saying it would be — out of scope to fix as a drive-by here (different, already-merged task), filed as `tasks/backlog/phase-1-core-pillars/P1-17-inference-service-ci-gap.md` per CLAUDE.md §10.

**Security/privacy self-audit**: this code touches vault master-key material (SE-wrapped + recovery-code-wrapped), all vault field/history/relationship data, and attachment/backup bytes. Protection: master key and all derived keys only ever live as `mlock`ed/zeroized `LockedBytes` while unlocked (`VaultLockController`); DB is SQLCipher-encrypted at rest (verified by test: no SQLite magic header, no plaintext substring, without the key); attachments are per-file AES-256-GCM with HKDF-derived per-file keys; backups are AES-256-GCM under a separate derived domain; every `VaultClient` call but `lockState()` requires a `PolicyTicket`, structurally checked with no bypass (mirrors `FakeVaultClient`) plus, at the `TicketVerifyingVaultClient` decorator layer, real HMAC verification and replay rejection; no `print(` in `Sources/VaultStore` (enforced by `NoPlaintextLoggingTests`); no network APIs anywhere in this package.

**Threat-model delta** (ARCHITECTURE.md §6.1 rows touched): vault-at-rest (DB/attachments/backups) — covered by SQLCipher + per-domain AES-GCM, tested. Vault-in-use (master key while unlocked) — covered by `LockedBytes` mlock/zeroize, not independently verifiable from outside the process in a unit test (documented limitation, same class as the SE-hardware gap). Ticket forgery/replay — covered by `TicketVerifyingVaultClient`, tested. Crypto-shred — covered by both the per-person (`cryptoShred`) and whole-vault (`MasterKeyManager.shredMasterKey`) paths, both tested via attempted-open-after-shred.

**Acceptance Criteria evidence**: "VaultAPI conformance suite passes against the real service" → `SQLCipherVaultStoreConformanceTests` (4/4 green). "DB file unreadable ciphertext without unlock" → `testDatabaseFileIsUnreadableCiphertextWithoutUnlock`. "ticket-less calls rejected" → `verifyTicketDiscipline` (conformance) + all of `TicketVerifyingVaultClientTests`. "crypto-shred verified by attempted-open test" → `verifyCryptoShred` (conformance, per-person) + `testShredMasterKeyMakesBothUnlockPathsPermanentlyFail` (whole-vault). "no plaintext value ever appears in logs/temp files" → `NoPlaintextLoggingTests` (source-grep) + `AttachmentStoreTests`/`BackupManagerTests`' ciphertext-on-disk assertions.

`Scripts/verify.sh VaultStore` → OK. `Scripts/check-boundaries.sh --all` → clean. `swift test --package-path Services/VaultService` → green.
