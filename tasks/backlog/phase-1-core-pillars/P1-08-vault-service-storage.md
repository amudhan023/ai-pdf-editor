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
