import Foundation

/// A conformance check failed. Carries a human-readable reason; test
/// targets turn these into failures with useful output. Identical shape to
/// `PDFEngineAPI.ConformanceFailure` — same purpose, different package.
public struct ConformanceFailure: Error, CustomStringConvertible {
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
    public var description: String { reason }
}

/// Protocol-conformance checks any real `VaultClient` implementation must
/// also pass — shipped here (not `Tests/`) so `VaultStore`'s future test
/// target can import `VaultAPI` and run the identical suite against the
/// SQLCipher-backed implementation once it exists (this task's Testing
/// Requirements: "conformance suite (reused against real Vault.xpc later)").
///
/// Tickets here are minted with a dummy `signature` — this suite exercises
/// only the structural contract (operation/scope/expiry) every
/// implementation must enforce; signature verification is PolicyKit's
/// concern and out of scope for this protocol layer entirely.
/// Vault-locked behavior is deliberately *not* covered here: locking is
/// implementation-specific (real unlock is a biometric/password flow), and
/// this protocol has no generic way to induce it — `FakeVaultClient`'s own
/// behavior tests cover that case directly.
public enum VaultConformanceSuite {
    public static func verifyProfileAndFieldCRUD<C: VaultClient>(_ client: C, person: Person) async throws {
        _ = try await client.createPerson(person, ticket: makeTicket(.write, person: person.id))

        let path = try FieldPath(validating: "identity.passport.number")
        let field = ProfileField(personID: person.id, path: path, value: .string(SecureBytes(utf8: "X1234567")))
        try await client.writeField(field, ticket: makeTicket(.write, person: person.id, paths: [path]))

        let read = try await client.readFields([path], for: person.id, ticket: makeTicket(.read, person: person.id, paths: [path]))
        guard read.first?.value == field.value else {
            throw ConformanceFailure("readFields must return the just-written value")
        }

        try await client.deleteField(path, for: person.id, ticket: makeTicket(.write, person: person.id, paths: [path]))
        var threwAfterDelete = false
        do {
            _ = try await client.readFields([path], for: person.id, ticket: makeTicket(.read, person: person.id, paths: [path]))
        } catch {
            threwAfterDelete = true
        }
        guard threwAfterDelete else { throw ConformanceFailure("readFields must throw for a deleted field") }
    }

    public static func verifyCompareRead<C: VaultClient>(_ client: C, person: Person) async throws {
        _ = try await client.createPerson(person, ticket: makeTicket(.write, person: person.id))
        let path = try FieldPath(validating: "identity.date_of_birth")
        let missing = try await client.compareRead(
            [path], for: person.id, ticket: makeTicket(.compareRead, person: person.id, paths: [path])
        )
        guard missing.first?.isPresent == false, missing.first?.valueFingerprint == nil else {
            throw ConformanceFailure("compareRead must report isPresent=false and no fingerprint for a missing field")
        }

        let field = ProfileField(personID: person.id, path: path, value: .date(Date(timeIntervalSince1970: 0)))
        try await client.writeField(field, ticket: makeTicket(.write, person: person.id, paths: [path]))
        let present = try await client.compareRead(
            [path], for: person.id, ticket: makeTicket(.compareRead, person: person.id, paths: [path])
        )
        guard present.first?.isPresent == true, present.first?.valueFingerprint == field.value.stableFingerprint() else {
            throw ConformanceFailure("compareRead must report isPresent=true and a matching fingerprint for a present field")
        }
    }

    public static func verifyTicketDiscipline<C: VaultClient>(_ client: C, person: Person) async throws {
        _ = try await client.createPerson(person, ticket: makeTicket(.write, person: person.id))
        let path = try FieldPath(validating: "identity.nationality")
        let field = ProfileField(personID: person.id, path: path, value: .enumeration("CA"))
        try await client.writeField(field, ticket: makeTicket(.write, person: person.id, paths: [path]))

        var threwForWrongOperation = false
        do {
            _ = try await client.readFields([path], for: person.id, ticket: makeTicket(.write, person: person.id, paths: [path]))
        } catch {
            threwForWrongOperation = true
        }
        guard threwForWrongOperation else { throw ConformanceFailure("a write-scoped ticket must not satisfy a read call") }

        var threwForWrongScope = false
        let unrelatedPath = try FieldPath(validating: "identity.passport.number")
        do {
            _ = try await client.readFields([path], for: person.id, ticket: makeTicket(.read, person: person.id, paths: [unrelatedPath]))
        } catch {
            threwForWrongScope = true
        }
        guard threwForWrongScope else { throw ConformanceFailure("a ticket scoped to a different path must not satisfy the call") }

        var threwForExpired = false
        let expired = PolicyTicket(
            operation: .read, personID: person.id, scopedPaths: [path],
            issuedAt: Date(timeIntervalSinceNow: -600), expiresAt: Date(timeIntervalSinceNow: -300), signature: Data()
        )
        do {
            _ = try await client.readFields([path], for: person.id, ticket: expired)
        } catch {
            threwForExpired = true
        }
        guard threwForExpired else { throw ConformanceFailure("an expired ticket must not satisfy the call") }
    }

    public static func verifyCryptoShred<C: VaultClient>(_ client: C, person: Person) async throws {
        _ = try await client.createPerson(person, ticket: makeTicket(.write, person: person.id))
        try await client.cryptoShred(person.id, ticket: makeTicket(.cryptoShred, person: person.id))

        var threwAfterShred = false
        do {
            _ = try await client.person(person.id, ticket: makeTicket(.read, person: person.id))
        } catch {
            threwAfterShred = true
        }
        guard threwAfterShred else { throw ConformanceFailure("person(_:) must throw after cryptoShred") }
    }

    private static func makeTicket(
        _ operation: VaultOperation,
        person: PersonID,
        paths: [FieldPath] = [],
        validFor: TimeInterval = 300
    ) -> PolicyTicket {
        let now = Date()
        return PolicyTicket(
            operation: operation, personID: person, scopedPaths: paths,
            issuedAt: now, expiresAt: now.addingTimeInterval(validFor), signature: Data()
        )
    }
}
