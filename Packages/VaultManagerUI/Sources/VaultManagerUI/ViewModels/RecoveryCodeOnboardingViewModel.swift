import Foundation

/// Drives the recovery-code one-time display ceremony (PRD "recovery-code
/// onboarding"): the code is revealed on demand, and the flow isn't
/// considered complete until the user explicitly acknowledges having saved
/// it. Persisting "already shown, never show again" is a composition-root
/// concern (where that flag lives is app storage, not this package's job)
/// — this view model only models the ceremony's own reveal/acknowledge
/// state for a single presentation.
@MainActor
public final class RecoveryCodeOnboardingViewModel: ObservableObject {
    @Published public private(set) var isRevealed = false
    @Published public private(set) var isAcknowledged = false

    public let recoveryCode: String

    public init(recoveryCode: String) {
        self.recoveryCode = recoveryCode
    }

    public func reveal() {
        isRevealed = true
    }

    public func acknowledge() {
        guard isRevealed else { return }
        isAcknowledged = true
    }
}
