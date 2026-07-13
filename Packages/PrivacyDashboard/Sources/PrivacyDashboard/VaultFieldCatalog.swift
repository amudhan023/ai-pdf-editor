import Foundation
import VaultAPI

/// The leaf paths `docs/specs/vault-schema.md` catalogs, grouped by
/// `FieldSection` — the fixed query set `StorageSummaryService` runs a
/// `compareRead` over to produce presence *counts*, never values (CLAUDE.md
/// §8.1). `.custom` has no catalog rows by definition (per-user extension),
/// so it's excluded here; a per-person custom-field count isn't derivable
/// without vault-side enumeration this package's frozen `VaultAPI` seam
/// doesn't expose (see this package's CLAUDE.md "Known Gaps").
///
/// Mirrors the doc rather than generating from it: `docs/specs/vault-schema.md`
/// remains the one owner of *which paths exist* (CLAUDE.md §10); adding a row
/// there without updating this list only understates a count, it never
/// fabricates one, since `compareRead` is queried per explicit path.
enum VaultFieldCatalog {
    static func leafPaths() throws -> [FieldSection: [FieldPath]] {
        var result: [FieldSection: [FieldPath]] = [:]
        for (section, raw) in rawPathsBySection {
            result[section] = try raw.map { try FieldPath(validating: $0) }
        }
        return result
    }

    private static let rawPathsBySection: [(FieldSection, [String])] = [
        (.identity, [
            "identity.legal_name.first",
            "identity.legal_name.middle",
            "identity.legal_name.last",
            "identity.preferred_name",
            "identity.date_of_birth",
            "identity.place_of_birth",
            "identity.nationality",
            "identity.ssn",
            "identity.passport.number",
            "identity.passport.issuing_country",
            "identity.passport.expiration_date",
            "identity.drivers_license.number",
            "identity.drivers_license.state",
            "identity.drivers_license.expiration_date"
        ]),
        (.contact, [
            "contact.address.line1",
            "contact.address.line2",
            "contact.address.city",
            "contact.address.state",
            "contact.address.postal_code",
            "contact.address.country",
            "contact.phone.mobile",
            "contact.phone.home",
            "contact.phone.work",
            "contact.email.primary",
            "contact.email.secondary"
        ]),
        (.employment, [
            "employment.current.employer_name",
            "employment.current.title",
            "employment.current.start_date",
            "employment.income.annual"
        ]),
        (.education, [
            "education.highest.institution_name",
            "education.highest.degree",
            "education.highest.field_of_study",
            "education.highest.graduation_date"
        ]),
        (.family, [
            "family.emergency_contact.name",
            "family.emergency_contact.phone"
        ]),
        (.financial, [
            "financial.bank.account_last4",
            "financial.bank.routing_number",
            "financial.business.ein"
        ]),
        (.health, [
            "health.insurance.provider",
            "health.insurance.policy_number",
            "health.physician.name",
            "health.allergies"
        ]),
        (.licenses, [
            "licenses.professional.name",
            "licenses.professional.number",
            "licenses.professional.expiration_date"
        ]),
        (.travel, [
            "travel.frequent_flyer.airline",
            "travel.frequent_flyer.number"
        ])
    ]
}
