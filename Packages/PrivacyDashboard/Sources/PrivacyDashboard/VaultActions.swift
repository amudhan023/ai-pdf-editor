import Foundation
import VaultAPI

/// MVP-level JSON export shape (this task's "export-vault entry point (JSON
/// schema export, MVP-level)"). Field values still travel as `SecureBytes`
/// until `VaultExportService` encodes the whole struct — the JSON encode is
/// the sanctioned "final write" boundary CLAUDE.md §7.3 describes, since the
/// caller explicitly requested a plaintext export of their own data.
public struct ExportedField: Codable, Sendable, Equatable {
    public let path: String
    public let value: FieldValue
    public let sensitivity: SensitivityTier
    public let verifiedAt: Date?
}

public struct ExportedProfile: Codable, Sendable, Equatable {
    public let personID: UUID
    public let kind: PersonKind
    public let displayName: String
    public let fields: [ExportedField]
    public let exportedAt: Date
}

/// Builds the MVP JSON export from already-present catalog fields (this
/// service does not invent a value for a field that isn't there — it skips
/// it, same as `StorageSummaryService`'s presence check).
public struct VaultExportService: Sendable {
    private let client: VaultClient
    private let encoder: JSONEncoder

    public init(client: VaultClient) {
        self.client = client
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        self.encoder = encoder
    }

    /// `ticket` must be a `.read` grant covering every catalog path for
    /// `person` — full disclosure, unlike the compare-only grant
    /// `StorageSummaryService` uses (CLAUDE.md §3.3: no bypass path).
    public func exportedProfile(for person: Person, ticket: PolicyTicket) async throws -> ExportedProfile {
        let catalog = try VaultFieldCatalog.leafPaths()
        var fields: [ExportedField] = []
        for (_, paths) in catalog {
            for path in paths {
                let field: ProfileField
                do {
                    guard let first = try await client.readFields([path], for: person.id, ticket: ticket).first else {
                        continue
                    }
                    field = first
                } catch VaultError.fieldNotFound {
                    continue
                }
                fields.append(ExportedField(
                    path: path.description, value: field.value, sensitivity: field.sensitivity, verifiedAt: field.verifiedAt
                ))
            }
        }
        return ExportedProfile(
            personID: person.id.value, kind: person.kind, displayName: person.displayName,
            fields: fields, exportedAt: Date()
        )
    }

    public func exportJSON(for person: Person, ticket: PolicyTicket) async throws -> Data {
        try encoder.encode(await exportedProfile(for: person, ticket: ticket))
    }
}

/// State machine for the "typed-confirmation ceremony" secure-erase flow
/// (this task's Vault actions requirement): the user must type the profile's
/// exact display name before `cryptoShred` runs — a structural guard against
/// a stray click destroying a profile, not just a "are you sure?" alert.
public enum SecureEraseState: Sendable, Equatable {
    case idle
    case confirming(expectedName: String)
    case erasing
    case erased
    case failed(PrivacyDashboardError)
}

public actor SecureEraseViewModel {
    private let client: VaultClient
    public private(set) var state: SecureEraseState = .idle

    public init(client: VaultClient) {
        self.client = client
    }

    public func beginConfirmation(for person: Person) {
        state = .confirming(expectedName: person.displayName)
    }

    public func cancel() {
        state = .idle
    }

    /// Returns `true` iff the erase actually ran. A typed-name mismatch is a
    /// normal user-input rejection (`PrivacyDashboardError.eraseConfirmationMismatch`),
    /// not a vault/system failure — it does not advance past `.confirming`.
    @discardableResult
    public func confirmErase(typedName: String, person: Person, ticket: PolicyTicket) async -> Bool {
        guard case .confirming(let expectedName) = state, typedName == expectedName else {
            state = .failed(.eraseConfirmationMismatch)
            return false
        }
        state = .erasing
        do {
            try await client.cryptoShred(person.id, ticket: ticket)
            state = .erased
            return true
        } catch {
            state = .failed(.underlyingVaultError(String(describing: error)))
            return false
        }
    }
}
