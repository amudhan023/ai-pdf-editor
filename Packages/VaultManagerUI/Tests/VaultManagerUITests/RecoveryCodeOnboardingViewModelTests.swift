import XCTest
@testable import VaultManagerUI

@MainActor
final class RecoveryCodeOnboardingViewModelTests: XCTestCase {
    func testAcknowledgeRequiresPriorReveal() {
        let viewModel = RecoveryCodeOnboardingViewModel(recoveryCode: "ABCD-EFGH-1234")

        viewModel.acknowledge()
        XCTAssertFalse(viewModel.isAcknowledged, "must not acknowledge before the code has been shown")

        viewModel.reveal()
        XCTAssertTrue(viewModel.isRevealed)

        viewModel.acknowledge()
        XCTAssertTrue(viewModel.isAcknowledged)
    }
}
