import Foundation
import VaultAPI

/// On-disk shape of `Resources/aliases.json`: one canonical vault path per
/// entry, with label variants keyed by BCP-47-ish language code ("en" is
/// required; others are locale extensions per the task's "top 5 languages"
/// requirement — coverage grows incrementally, see the curation guide in
/// this package's CLAUDE.md).
private struct AliasEntry: Codable {
    let vaultPath: String
    let labels: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case vaultPath = "vault_path"
        case labels
    }
}

private struct AliasFile: Codable {
    let schemaVersion: Int
    let entries: [AliasEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case entries
    }
}

/// The curated top-N label -> vault-path dictionary (matching-ladder rung
/// 1). Lookup is exact-match on a `LabelNormalizer.normalize`d string —
/// deterministic and total, per CLAUDE.md §2 "deterministic first."
public struct AliasDictionary: Sendable {
    private let pathsByNormalizedLabel: [String: FieldPath]

    /// All canonical vault paths this dictionary knows about, for the
    /// embedding rung to build its candidate set from.
    public let knownPaths: [FieldPath]

    init(pathsByNormalizedLabel: [String: FieldPath], knownPaths: [FieldPath]) {
        self.pathsByNormalizedLabel = pathsByNormalizedLabel
        self.knownPaths = knownPaths
    }

    public func lookup(normalizedLabel: String) -> FieldPath? {
        pathsByNormalizedLabel[normalizedLabel]
    }

    /// Loads the bundled `Resources/aliases.json`. Throws rather than
    /// crashing on a malformed resource — a build-time defect, but still a
    /// typed failure per CLAUDE.md §15, not a `fatalError`.
    public static func bundled() throws -> AliasDictionary {
        guard let url = Bundle.module.url(forResource: "aliases", withExtension: "json") else {
            throw AutofillEngineError.aliasDictionaryUnavailable(reason: "aliases.json not found in bundle")
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> AliasDictionary {
        let file = try JSONDecoder().decode(AliasFile.self, from: data)
        var pathsByLabel: [String: FieldPath] = [:]
        var knownPaths: [FieldPath] = []
        for entry in file.entries {
            let path = try FieldPath(validating: entry.vaultPath)
            knownPaths.append(path)
            for variants in entry.labels.values {
                for variant in variants {
                    pathsByLabel[LabelNormalizer.normalize(variant)] = path
                }
            }
        }
        return AliasDictionary(pathsByNormalizedLabel: pathsByLabel, knownPaths: knownPaths)
    }
}
