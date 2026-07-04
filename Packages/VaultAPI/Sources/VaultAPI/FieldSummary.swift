import Foundation

/// The result of a `compareRead` — enough to detect a conflict (ARCHITECTURE.md
/// §5.1's ingestion "read existing values (compare-only grant)" ->
/// "current field summaries") without disclosing the underlying value the
/// way a full `readFields` grant would. `valueFingerprint` is
/// `FieldValue.stableFingerprint()`'s output, `nil` when the field isn't
/// present at all.
public struct FieldSummary: Sendable, Codable, Equatable {
    public let path: FieldPath
    public let isPresent: Bool
    public let sensitivity: SensitivityTier
    public let verifiedAt: Date?
    public let valueFingerprint: String?

    public init(
        path: FieldPath,
        isPresent: Bool,
        sensitivity: SensitivityTier,
        verifiedAt: Date?,
        valueFingerprint: String?
    ) {
        self.path = path
        self.isPresent = isPresent
        self.sensitivity = sensitivity
        self.verifiedAt = verifiedAt
        self.valueFingerprint = valueFingerprint
    }
}
