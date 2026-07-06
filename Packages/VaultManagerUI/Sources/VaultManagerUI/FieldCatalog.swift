import Foundation
import VaultAPI

/// The section-organized field catalog the UI renders editors for. Mirrors
/// `docs/specs/vault-schema.md` (the one owner of "which paths exist" per
/// CLAUDE.md §5) — this is the UI-layer projection of that doc, not a
/// second source of truth: `VaultClient` has no "list fields" method, so
/// the sidebar/detail views must know which paths to ask about up front.
public enum FieldCatalog {
    public struct Entry: Sendable {
        public let path: FieldPath
        public let label: String
        public let defaultSensitivity: SensitivityTier
    }

    public static func entries(for section: FieldSection) -> [Entry] {
        catalog[section] ?? []
    }

    /// Builds a catalog row from a literal path string. Every literal here
    /// is a known-good entry from `docs/specs/vault-schema.md`; a typo would
    /// be caught immediately by `FieldCatalogTests` (every entry round-trips
    /// through `FieldPath(validating:)`), so a parse failure at runtime
    /// (never observed) degrades to "row omitted" rather than a force-unwrap
    /// crash on an input-adjacent path (CLAUDE.md §4/§15).
    private static func entry(_ raw: String, _ label: String, _ sensitivity: SensitivityTier) -> Entry? {
        guard let path = try? FieldPath(validating: raw) else { return nil }
        return Entry(path: path, label: label, defaultSensitivity: sensitivity)
    }

    private static let catalog: [FieldSection: [Entry]] = rawCatalog.mapValues { $0.compactMap { $0 } }

    private static let rawCatalog: [FieldSection: [Entry?]] = [
        .identity: [
            entry("identity.legal_name.first", "First Name", .standard),
            entry("identity.legal_name.middle", "Middle Name", .standard),
            entry("identity.legal_name.last", "Last Name", .standard),
            entry("identity.preferred_name", "Preferred Name", .standard),
            entry("identity.date_of_birth", "Date of Birth", .sensitive),
            entry("identity.place_of_birth", "Place of Birth", .standard),
            entry("identity.ssn", "SSN", .sensitive),
            entry("identity.passport.number", "Passport Number", .sensitive),
            entry("identity.passport.issuing_country", "Passport Issuing Country", .standard),
            entry("identity.passport.expiration_date", "Passport Expiration", .standard)
        ],
        .contact: [
            entry("contact.address.line1", "Address Line 1", .standard),
            entry("contact.address.line2", "Address Line 2", .standard),
            entry("contact.address.city", "City", .standard),
            entry("contact.address.state", "State", .standard),
            entry("contact.address.postal_code", "Postal Code", .standard),
            entry("contact.phone.mobile", "Mobile Phone", .standard),
            entry("contact.email.primary", "Primary Email", .standard)
        ],
        .employment: [
            entry("employment.current.employer_name", "Employer", .standard),
            entry("employment.current.title", "Title", .standard),
            entry("employment.income.annual", "Annual Income", .sensitive)
        ],
        .financial: [
            entry("financial.bank.account_last4", "Account (last 4)", .sensitive),
            entry("financial.bank.routing_number", "Routing Number", .sensitive)
        ]
    ]
}
