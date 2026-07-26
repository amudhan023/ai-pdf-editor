import Foundation
import VaultAPI

/// A composite label ("Full Name", "Mailing Address") decomposes into more
/// than one vault leaf field, in a fixed order the caller (ValueFormatter,
/// P2-05) consumes positionally — this is deliberately not a
/// `MatchCandidate`, since a single score/source pair doesn't describe a
/// multi-field plan.
public struct CompositeMatch: Sendable, Equatable {
    public let parts: [FieldPath]

    public init(parts: [FieldPath]) {
        self.parts = parts
    }
}

private struct CompositeEntry: Codable {
    let vaultPaths: [String]
    let labels: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case vaultPaths = "vault_paths"
        case labels
    }
}

private struct CompositeFile: Codable {
    let schemaVersion: Int
    let entries: [CompositeEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case entries
    }
}

/// Curated composite-label -> multi-path decomposition table (matching
/// ladder's pre-dictionary step): checked *before* `AliasDictionary`, since
/// a composite label like "full name" should never resolve to a single
/// leaf path even if some other curated entry could technically match a
/// substring of it.
///
/// Deliberately excludes bare "address" (already a single-path dictionary
/// entry -> `contact.address.line1` in `aliases.json`, curated for
/// single-line address fields, which are common and a legitimate distinct
/// case from a multi-line mailing-address block) — only the unambiguously
/// multi-field phrasings ("mailing address", "full address", "complete
/// address") are composite here, so this table doesn't contradict that
/// existing curated entry.
public struct CompositeDictionary: Sendable {
    private let partsByNormalizedLabel: [String: [FieldPath]]

    init(partsByNormalizedLabel: [String: [FieldPath]]) {
        self.partsByNormalizedLabel = partsByNormalizedLabel
    }

    public func lookup(normalizedLabel: String) -> CompositeMatch? {
        partsByNormalizedLabel[normalizedLabel].map(CompositeMatch.init(parts:))
    }

    public static func bundled() throws -> CompositeDictionary {
        guard let url = Bundle.module.url(forResource: "composite_aliases", withExtension: "json") else {
            throw AutofillEngineError.aliasDictionaryUnavailable(reason: "composite_aliases.json not found in bundle")
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> CompositeDictionary {
        let file = try JSONDecoder().decode(CompositeFile.self, from: data)
        var partsByLabel: [String: [FieldPath]] = [:]
        for entry in file.entries {
            let paths = try entry.vaultPaths.map { try FieldPath(validating: $0) }
            for variants in entry.labels.values {
                for variant in variants {
                    partsByLabel[LabelNormalizer.normalize(variant)] = paths
                }
            }
        }
        return CompositeDictionary(partsByNormalizedLabel: partsByLabel)
    }
}
