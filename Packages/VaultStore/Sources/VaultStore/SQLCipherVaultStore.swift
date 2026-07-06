import Foundation
import GRDB
import VaultAPI

/// The real, SQLCipher-backed `VaultClient` (ARCHITECTURE.md §8.1/§8.2).
/// Single-writer via GRDB's `DatabasePool` (WAL mode by default), keyed
/// with the raw (non-passphrase-derived) DB key from `VaultLockController`
/// so the whole file is unreadable ciphertext without it.
///
/// Structural ticket enforcement here mirrors `VaultAPI.FakeVaultClient`
/// exactly (operation/person-scope/path-scope/expiry — CLAUDE.md §3.3: "no
/// bypass path") so `VaultAPI.VaultConformanceSuite` runs against this type
/// unmodified. Cryptographic signature verification and replay rejection
/// are a separate, composable layer (`TicketVerifyingVaultClient`) — see
/// that type's doc comment for why the split matches the conformance
/// suite's own documented scope.
public actor SQLCipherVaultStore: VaultClient {
    private let dbURL: URL
    private let lockController: VaultLockController
    private var dbPool: DatabasePool?

    /// Vault access events (P1-10) — see `VaultAccessEvent`'s doc comment.
    /// A narrow `AsyncStream` per package convention (`VaultLockEvent`'s
    /// precedent), not a general-purpose event bus (P1-15's scope).
    public nonisolated let accessEvents: AsyncStream<VaultAccessEvent>
    private let accessEventContinuation: AsyncStream<VaultAccessEvent>.Continuation

    public init(dbURL: URL, lockController: VaultLockController) {
        self.dbURL = dbURL
        self.lockController = lockController
        (accessEvents, accessEventContinuation) = AsyncStream.makeStream(of: VaultAccessEvent.self)
    }

    func emitAccess(_ operation: VaultOperation, person: PersonID, paths: [FieldPath] = [], ticket: PolicyTicket) {
        accessEventContinuation.yield(VaultAccessEvent(operation: operation, personID: person, paths: paths, ticketID: ticket.id, at: Date()))
    }

    // MARK: - Lock lifecycle

    public func unlock() async throws {
        guard dbPool == nil else { return }
        try await lockController.unlock()
        try await openPool()
    }

    public func unlock(recoveryCode: RecoveryCode) async throws {
        guard dbPool == nil else { return }
        try await lockController.unlock(recoveryCode: recoveryCode)
        try await openPool()
    }

    public func lock() async {
        dbPool = nil
        await lockController.lock()
    }

    public func lockState() async -> VaultLockState {
        await lockController.lockState
    }

    private func openPool() async throws {
        let dbKey = try await lockController.databaseKey()
        var config = Configuration()
        config.prepareDatabase { db in
            let hex = dbKey.withUnsafeBytes { Data($0) }.map { String(format: "%02x", $0) }.joined()
            try db.execute(sql: "PRAGMA key = \"x'\(hex)'\"")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA secure_delete = ON")
        }
        let pool = try DatabasePool(path: dbURL.path, configuration: config)
        try VaultMigrations.migrator.migrate(pool)
        dbPool = pool
    }

    // `internal` rather than `private`: the Operations/ extensions
    // (batch accept-set, history date-range queries) are additional
    // capabilities on the concrete store beyond the frozen `VaultClient`
    // seam (ADR-007), so they live in their own files but still need this
    // and `checkTicket` below.
    func openedPool() throws -> DatabasePool {
        guard let dbPool else { throw VaultError.vaultLocked }
        return dbPool
    }

    // MARK: - Persons

    public func createPerson(_ person: Person, ticket: PolicyTicket) async throws -> Person {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: person.id)
        emitAccess(.write, person: person.id, ticket: ticket)
        try await pool.write { db in
            try PersonRow(person).insert(db)
        }
        return person
    }

    public func person(_ id: PersonID, ticket: PolicyTicket) async throws -> Person {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .read, person: id)
        emitAccess(.read, person: id, ticket: ticket)
        guard let row = try await pool.read({ db in try PersonRow.fetchOne(db, key: id.value.uuidString) }) else {
            throw VaultError.personNotFound(id)
        }
        return try row.asDomain()
    }

    public func deletePerson(_ id: PersonID, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: id)
        emitAccess(.write, person: id, ticket: ticket)
        let deleted = try await pool.write { db in try PersonRow.deleteOne(db, key: id.value.uuidString) }
        guard deleted else { throw VaultError.personNotFound(id) }
    }

    // MARK: - Fields

    public func writeField(_ field: ProfileField, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: field.personID, path: field.path)
        emitAccess(.write, person: field.personID, paths: [field.path], ticket: ticket)
        let row = try ProfileFieldRow(field)
        try await pool.write { db in
            guard try PersonRow.filter(key: field.personID.value.uuidString).fetchCount(db) > 0 else {
                throw VaultError.personNotFound(field.personID)
            }
            try row.save(db)
        }
    }

    public func readFields(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [ProfileField] {
        let pool = try openedPool()
        for path in paths {
            try checkTicket(ticket, operation: .read, person: person, path: path)
        }
        emitAccess(.read, person: person, paths: paths, ticket: ticket)
        return try await pool.read { db in
            try paths.map { path in
                guard let row = try ProfileFieldRow.fetchOne(
                    db,
                    key: ["personID": person.value.uuidString, "path": path.description]
                ) else {
                    throw VaultError.fieldNotFound(path)
                }
                return try row.asDomain()
            }
        }
    }

    public func deleteField(_ path: FieldPath, for person: PersonID, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: person, path: path)
        emitAccess(.write, person: person, paths: [path], ticket: ticket)
        let deleted = try await pool.write { db in
            try ProfileFieldRow.deleteOne(db, key: ["personID": person.value.uuidString, "path": path.description])
        }
        guard deleted else { throw VaultError.fieldNotFound(path) }
    }

    public func compareRead(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [FieldSummary] {
        let pool = try openedPool()
        for path in paths {
            try checkTicket(ticket, operation: .compareRead, person: person, path: path)
        }
        emitAccess(.compareRead, person: person, paths: paths, ticket: ticket)
        return try await pool.read { db in
            try paths.map { path in
                guard let row = try ProfileFieldRow.fetchOne(
                    db,
                    key: ["personID": person.value.uuidString, "path": path.description]
                ) else {
                    return FieldSummary(path: path, isPresent: false, sensitivity: .standard, verifiedAt: nil, valueFingerprint: nil)
                }
                let field = try row.asDomain()
                return FieldSummary(
                    path: path,
                    isPresent: true,
                    sensitivity: field.sensitivity,
                    verifiedAt: field.verifiedAt,
                    valueFingerprint: field.value.stableFingerprint()
                )
            }
        }
    }

    // MARK: - History

    public func writeHistoryEntry(_ entry: HistoryEntry, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: entry.personID)
        emitAccess(.write, person: entry.personID, ticket: ticket)
        let entryRow = HistoryEntryRow(entry)
        let fieldRows = try entry.fields.map { try HistoryFieldEntryRow(historyEntryID: entry.id.uuidString, field: $0) }
        try await pool.write { db in
            guard try PersonRow.filter(key: entry.personID.value.uuidString).fetchCount(db) > 0 else {
                throw VaultError.personNotFound(entry.personID)
            }
            try entryRow.save(db)
            try db.execute(sql: "DELETE FROM historyFieldEntry WHERE historyEntryID = ?", arguments: [entry.id.uuidString])
            for row in fieldRows {
                try row.insert(db)
            }
        }
    }

    public func historyEntries(category: HistoryCategory, for person: PersonID, ticket: PolicyTicket) async throws -> [HistoryEntry] {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .read, person: person)
        emitAccess(.read, person: person, ticket: ticket)
        return try await pool.read { db in
            let entryRows = try HistoryEntryRow
                .filter(Column("personID") == person.value.uuidString && Column("category") == category.rawValue)
                .fetchAll(db)
            return try entryRows.map { entryRow in
                let fieldRows = try HistoryFieldEntryRow
                    .filter(Column("historyEntryID") == entryRow.id)
                    .fetchAll(db)
                let fields = try fieldRows.map { try $0.asDomain() }
                return try entryRow.asDomain(fields: fields)
            }
        }
    }

    public func deleteHistoryEntry(_ id: HistoryEntry.ID, for person: PersonID, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: person)
        emitAccess(.write, person: person, ticket: ticket)
        let deleted = try await pool.write { db in try HistoryEntryRow.deleteOne(db, key: id.uuidString) }
        guard deleted else { throw VaultError.historyEntryNotFound(id) }
    }

    // MARK: - Relationships

    public func addRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: edge.from)
        emitAccess(.write, person: edge.from, ticket: ticket)
        try await pool.write { db in
            guard try PersonRow.filter(key: edge.from.value.uuidString).fetchCount(db) > 0 else {
                throw VaultError.personNotFound(edge.from)
            }
            guard try PersonRow.filter(key: edge.toPersonID.value.uuidString).fetchCount(db) > 0 else {
                throw VaultError.personNotFound(edge.toPersonID)
            }
            try RelationshipEdgeRow(edge).insert(db)
        }
    }

    public func relationships(for person: PersonID, ticket: PolicyTicket) async throws -> [RelationshipEdge] {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .read, person: person)
        emitAccess(.read, person: person, ticket: ticket)
        return try await pool.read { db in
            let rows = try RelationshipEdgeRow
                .filter(Column("fromPersonID") == person.value.uuidString || Column("toPersonID") == person.value.uuidString)
                .fetchAll(db)
            return try rows.map { try $0.asDomain() }
        }
    }

    public func removeRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .write, person: edge.from)
        emitAccess(.write, person: edge.from, ticket: ticket)
        let row = RelationshipEdgeRow(edge)
        let deleted = try await pool.write { db in
            try RelationshipEdgeRow
                .filter(Column("fromPersonID") == row.fromPersonID)
                .filter(Column("toPersonID") == row.toPersonID)
                .filter(Column("kindTag") == row.kindTag)
                .filter(row.kindLabel.map { Column("kindLabel") == $0 } ?? Column("kindLabel") == nil)
                .deleteAll(db)
        }
        guard deleted > 0 else { throw VaultError.relationshipNotFound }
    }

    // MARK: - Crypto-shred (per-person)

    /// Hard cascade-delete under `PRAGMA secure_delete = ON` (freed pages
    /// are overwritten, not just unlinked) — the per-person leg of
    /// crypto-shred. Whole-vault crypto-shred (destroying the master key
    /// itself, so the entire file becomes unrecoverable ciphertext) is
    /// `MasterKeyManager.shredMasterKey()`, a different and stronger
    /// operation; `VaultClient.cryptoShred` only commits to the
    /// per-person observable effect (see that protocol method's doc comment).
    public func cryptoShred(_ person: PersonID, ticket: PolicyTicket) async throws {
        let pool = try openedPool()
        try checkTicket(ticket, operation: .cryptoShred, person: person)
        emitAccess(.cryptoShred, person: person, ticket: ticket)
        let deleted = try await pool.write { db in try PersonRow.deleteOne(db, key: person.value.uuidString) }
        guard deleted else { throw VaultError.personNotFound(person) }
    }

    // MARK: - Structural ticket enforcement (CLAUDE.md §3.3 "no bypass path")
    //
    // Deliberately duplicated from FakeVaultClient rather than shared across
    // packages: both are the same ~15-line contract check, but sharing it
    // would mean adding new API surface to the frozen VaultAPI seam
    // (ADR-007) for an internal helper — not worth it for this size, and
    // VaultConformanceSuite already pins the contract both must satisfy.

    func checkTicket(
        _ ticket: PolicyTicket,
        operation: VaultOperation,
        person: PersonID,
        path: FieldPath? = nil,
        now: Date = Date()
    ) throws {
        guard ticket.operation == operation else {
            throw VaultError.ticketOperationMismatch(expected: operation, got: ticket.operation)
        }
        guard ticket.personID == person else {
            throw VaultError.ticketScopeMismatch(operation: operation, path: path)
        }
        if let path, !ticket.covers(path) {
            throw VaultError.ticketScopeMismatch(operation: operation, path: path)
        }
        guard ticket.isTemporallyValid(at: now) else {
            throw VaultError.ticketExpired
        }
    }
}
