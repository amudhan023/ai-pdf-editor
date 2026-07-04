import Foundation

/// Field sensitivity tier (PRD FR-2.5). `.sensitive` fields are masked in
/// UI by default, require re-auth to reveal, and require explicit
/// per-fill confirmation — those behaviors live in the consuming UI/session
/// layers; this package only carries the classification.
public enum SensitivityTier: String, Sendable, Codable, CaseIterable, Equatable {
    case standard
    case sensitive
}
