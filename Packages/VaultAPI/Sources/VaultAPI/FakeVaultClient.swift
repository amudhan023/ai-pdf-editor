import Foundation

/// In-memory `VaultClient` for consumers' tests (CLAUDE.md §5's `Fake*`
/// naming: shipped in the API package, not a test-local `Mock*`). Enforces
/// the same structural ticket checks (operation/person/path-scope/expiry) a
/// real implementation must — it just trusts `PolicyTicket.signature`
/// unconditionally, since verifying it is PolicyKit's job, not this
/// protocol's (see `PolicyTicket`'s doc comment).
public actor FakeVaultClient: VaultClient {
    private var lock: VaultLockState = .unlocked
    private var persons: [PersonID: Person] = [:]
    private var fields: [PersonID: [FieldPath: ProfileField]] = [:]
    private var histories: [PersonID: [HistoryEntry]] = [:]
    private var edges: [RelationshipEdge] = []

    public init() {}

    // MARK: - Fake-only test seeding (not part of VaultClient)

    public func setLockState(_ state: VaultLockState) {
        lock = state
    }

    // MARK: - VaultClient

    public func lockState() async -> VaultLockState {
        lock
    }

    public func createPerson(_ person: Person, ticket: PolicyTicket) async throws -> Person {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: person.id)
        persons[person.id] = person
        if fields[person.id] == nil { fields[person.id] = [:] }
        return person
    }

    public func person(_ id: PersonID, ticket: PolicyTicket) async throws -> Person {
        try checkLock()
        try checkTicket(ticket, operation: .read, person: id)
        guard let person = persons[id] else { throw VaultError.personNotFound(id) }
        return person
    }

    public func deletePerson(_ id: PersonID, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: id)
        guard persons.removeValue(forKey: id) != nil else { throw VaultError.personNotFound(id) }
        fields.removeValue(forKey: id)
        histories.removeValue(forKey: id)
        edges.removeAll { $0.from == id || $0.toPersonID == id }
    }

    public func writeField(_ field: ProfileField, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: field.personID, path: field.path)
        guard persons[field.personID] != nil else { throw VaultError.personNotFound(field.personID) }
        fields[field.personID, default: [:]][field.path] = field
    }

    public func readFields(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [ProfileField] {
        try checkLock()
        for path in paths {
            try checkTicket(ticket, operation: .read, person: person, path: path)
        }
        let store = fields[person] ?? [:]
        return try paths.map { path in
            guard let field = store[path] else { throw VaultError.fieldNotFound(path) }
            return field
        }
    }

    public func deleteField(_ path: FieldPath, for person: PersonID, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: person, path: path)
        guard fields[person]?.removeValue(forKey: path) != nil else { throw VaultError.fieldNotFound(path) }
    }

    public func compareRead(_ paths: [FieldPath], for person: PersonID, ticket: PolicyTicket) async throws -> [FieldSummary] {
        try checkLock()
        for path in paths {
            try checkTicket(ticket, operation: .compareRead, person: person, path: path)
        }
        let store = fields[person] ?? [:]
        return paths.map { path in
            guard let field = store[path] else {
                return FieldSummary(path: path, isPresent: false, sensitivity: .standard, verifiedAt: nil, valueFingerprint: nil)
            }
            return FieldSummary(
                path: path,
                isPresent: true,
                sensitivity: field.sensitivity,
                verifiedAt: field.verifiedAt,
                valueFingerprint: field.value.stableFingerprint()
            )
        }
    }

    public func writeHistoryEntry(_ entry: HistoryEntry, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: entry.personID)
        guard persons[entry.personID] != nil else { throw VaultError.personNotFound(entry.personID) }
        var entries = histories[entry.personID] ?? []
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        histories[entry.personID] = entries
    }

    public func historyEntries(category: HistoryCategory, for person: PersonID, ticket: PolicyTicket) async throws -> [HistoryEntry] {
        try checkLock()
        try checkTicket(ticket, operation: .read, person: person)
        return (histories[person] ?? []).filter { $0.category == category }
    }

    public func deleteHistoryEntry(_ id: HistoryEntry.ID, for person: PersonID, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: person)
        guard let entries = histories[person], entries.contains(where: { $0.id == id }) else {
            throw VaultError.historyEntryNotFound(id)
        }
        histories[person]?.removeAll { $0.id == id }
    }

    public func addRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: edge.from)
        guard persons[edge.from] != nil else { throw VaultError.personNotFound(edge.from) }
        guard persons[edge.toPersonID] != nil else { throw VaultError.personNotFound(edge.toPersonID) }
        edges.append(edge)
    }

    public func relationships(for person: PersonID, ticket: PolicyTicket) async throws -> [RelationshipEdge] {
        try checkLock()
        try checkTicket(ticket, operation: .read, person: person)
        return edges.filter { $0.from == person || $0.toPersonID == person }
    }

    public func removeRelationship(_ edge: RelationshipEdge, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .write, person: edge.from)
        guard let index = edges.firstIndex(of: edge) else { throw VaultError.relationshipNotFound }
        edges.remove(at: index)
    }

    public func cryptoShred(_ person: PersonID, ticket: PolicyTicket) async throws {
        try checkLock()
        try checkTicket(ticket, operation: .cryptoShred, person: person)
        guard persons.removeValue(forKey: person) != nil else { throw VaultError.personNotFound(person) }
        fields.removeValue(forKey: person)
        histories.removeValue(forKey: person)
        edges.removeAll { $0.from == person || $0.toPersonID == person }
    }

    // MARK: - Structural enforcement (CLAUDE.md §3.3 "no bypass path")

    private func checkLock() throws {
        guard lock == .unlocked else { throw VaultError.vaultLocked }
    }

    private func checkTicket(
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
