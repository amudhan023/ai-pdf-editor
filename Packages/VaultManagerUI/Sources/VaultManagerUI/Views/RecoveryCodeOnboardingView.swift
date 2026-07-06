import SwiftUI

public struct RecoveryCodeOnboardingView: View {
    @ObservedObject private var viewModel: RecoveryCodeOnboardingViewModel
    public var onComplete: () -> Void

    public init(viewModel: RecoveryCodeOnboardingViewModel, onComplete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Your Recovery Code")
                .font(.title2)
            Text(
                "Write this down and store it somewhere safe. It's the only way to unlock your vault "
                + "if you lose access to Touch ID/password. It will not be shown again."
            )
                .font(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if viewModel.isRevealed {
                Text(viewModel.recoveryCode)
                    .font(.system(.title3, design: .monospaced))
                    .padding()
                    .background(.quaternary)
                    .textSelection(.enabled)
            } else {
                Button("Reveal Recovery Code") { viewModel.reveal() }
                    .buttonStyle(.borderedProminent)
            }

            if viewModel.isRevealed {
                Button("I've saved my recovery code") {
                    viewModel.acknowledge()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }
}
