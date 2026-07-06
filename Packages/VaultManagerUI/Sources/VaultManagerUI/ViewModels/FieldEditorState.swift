import Foundation
import VaultAPI

/// UI-facing state for one vault field. `revealedValue` is deliberately
/// `nil` for a present-but-masked sensitive field — the view model never
/// fetches a sensitive value's plaintext until the user explicitly reveals
/// it (`ProfileDetailViewModel.reveal(_:)`), so a masked row's state never
/// even holds the value in memory, let alone the view.
public struct FieldEditorState: Sendable, Equatable {
    public var path: FieldPath
    public var isPresent: Bool
    public var sensitivity: SensitivityTier
    public var verifiedAt: Date?
    public var revealedValue: FieldValue?
    public var isRevealed: Bool

    public init(
        path: FieldPath,
        isPresent: Bool,
        sensitivity: SensitivityTier,
        verifiedAt: Date?,
        revealedValue: FieldValue?,
        isRevealed: Bool
    ) {
        self.path = path
        self.isPresent = isPresent
        self.sensitivity = sensitivity
        self.verifiedAt = verifiedAt
        self.revealedValue = revealedValue
        self.isRevealed = isRevealed
    }

    /// Whether the row should render masked ("••••••") — sensitive fields
    /// with no active reveal, present or not (an unset sensitive field still
    /// masks its "empty" placeholder, matching FR-2.5's "masked by default").
    public var isMasked: Bool { sensitivity == .sensitive && !isRevealed }
}
