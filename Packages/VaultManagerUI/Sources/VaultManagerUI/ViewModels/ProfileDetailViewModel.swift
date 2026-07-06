import Foundation
import VaultAPI

/// Drives one profile's section/field editors. Sensitive fields load via
/// `compareRead` only (presence/sensitivity/verifiedAt, never the value) so
/// a masked field's plaintext is never fetched, let alone held in memory,
/// until `reveal(_:)` — the reveal path requests a `.read` ticket instead
/// and only proceeds once the ticket provider grants it (a stale-auth
/// sensitive field surfaces as `reauthRequired`, not a thrown error).
@MainActor
public final class ProfileDetailViewModel: ObservableObject {
    @Published public private(set) var fields: [FieldPath: FieldEditorState] = [:]
    @Published public private(set) var lastError: VaultError?
    @Published public private(set) var reauthRequired: FieldPath?

    public let personID: PersonID
    private let client: any VaultClient
    private let tickets: any VaultTicketProviding
    private let auditing: any VaultRevealAuditing

    public init(
        personID: PersonID,
        client: any VaultClient,
        tickets: any VaultTicketProviding,
        auditing: any VaultRevealAuditing
    ) {
        self.personID = personID
        self.client = client
        self.tickets = tickets
        self.auditing = auditing
    }

    /// Loads every path in `catalog` (the section's known field-path list,
    /// per `docs/specs/vault-schema.md` — `VaultClient` has no "list all
    /// fields" method, so the UI must ask for known paths explicitly).
    public func load(catalog: [FieldPath]) async {
        for path in catalog {
            await loadOne(path)
        }
    }

    private func loadOne(_ path: FieldPath) async {
        do {
            // `.standard` here regardless of the field's real sensitivity: a
            // compareRead never discloses the value (ARCHITECTURE.md §5.1),
            // so gating it behind reauth would add friction without a
            // matching disclosure risk — only the later full `.read` (in
            // `reveal`/`readValue`) passes the field's actual sensitivity.
            let ticket = try await tickets.requestTicket(
                operation: .compareRead, personID: personID, scopedPaths: [path], sensitivity: .standard
            )
            guard let summary = try await client.compareRead([path], for: personID, ticket: ticket).first else { return }
            var state = FieldEditorState(
                path: path, isPresent: summary.isPresent, sensitivity: summary.sensitivity,
                verifiedAt: summary.verifiedAt, revealedValue: nil, isRevealed: false
            )
            if summary.isPresent, summary.sensitivity == .standard, let value = try? await readValue(path, sensitivity: .standard) {
                state.revealedValue = value
                state.isRevealed = true
            }
            fields[path] = state
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure on load is non-fatal: the row just stays unloaded.
        }
    }

    private func readValue(_ path: FieldPath, sensitivity: SensitivityTier) async throws -> FieldValue {
        let ticket = try await tickets.requestTicket(
            operation: .read, personID: personID, scopedPaths: [path], sensitivity: sensitivity
        )
        guard let field = try await client.readFields([path], for: personID, ticket: ticket).first else {
            throw VaultError.fieldNotFound(path)
        }
        return field.value
    }

    public func reveal(_ path: FieldPath) async {
        guard let existing = fields[path], existing.isPresent, !existing.isRevealed else { return }
        do {
            let value = try await readValue(path, sensitivity: existing.sensitivity)
            var state = existing
            state.revealedValue = value
            state.isRevealed = true
            fields[path] = state
            auditing.recordReveal(path: path, personID: personID)
            reauthRequired = nil
        } catch VaultTicketRequestError.reauthRequired {
            reauthRequired = path
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Other ticket-provider failures leave the field masked, not crashed.
        }
    }

    /// Re-masks a sensitive field the user previously revealed. No-op for
    /// standard fields (they're never masked in the first place).
    public func rehide(_ path: FieldPath) {
        guard var state = fields[path], state.sensitivity == .sensitive else { return }
        state.revealedValue = nil
        state.isRevealed = false
        fields[path] = state
    }

    public func writeValue(
        _ path: FieldPath,
        value: FieldValue,
        sensitivity: SensitivityTier,
        aliases: [String] = [],
        provenance: Provenance = .manual
    ) async {
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [path], sensitivity: sensitivity
            )
            let field = ProfileField(
                personID: personID, path: path, value: value, sensitivity: sensitivity,
                aliases: aliases, verifiedAt: nil, provenance: provenance
            )
            try await client.writeField(field, ticket: ticket)
            fields[path] = FieldEditorState(
                path: path, isPresent: true, sensitivity: sensitivity, verifiedAt: nil,
                revealedValue: value, isRevealed: true
            )
            reauthRequired = nil
        } catch VaultTicketRequestError.reauthRequired {
            reauthRequired = path
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure: leave prior state untouched.
        }
    }

    public func deleteValue(_ path: FieldPath) async {
        let sensitivity = fields[path]?.sensitivity ?? .standard
        do {
            let ticket = try await tickets.requestTicket(
                operation: .write, personID: personID, scopedPaths: [path], sensitivity: sensitivity
            )
            try await client.deleteField(path, for: personID, ticket: ticket)
            fields[path] = FieldEditorState(
                path: path, isPresent: false, sensitivity: sensitivity, verifiedAt: nil,
                revealedValue: nil, isRevealed: false
            )
        } catch let error as VaultError {
            lastError = error
        } catch {
            // Ticket-provider failure: leave prior state untouched.
        }
    }
}
