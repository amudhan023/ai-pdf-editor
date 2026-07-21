import SwiftUI

public struct UnlockView: View {
    @ObservedObject private var viewModel: VaultUnlockViewModel

    public init(viewModel: VaultUnlockViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 40))
            Text("Vault Locked").font(.title2)
            Button("Unlock with Touch ID") {
                Task { await viewModel.unlock() }
            }
            .keyboardShortcut(.defaultAction)
            if let message = viewModel.unlockErrorMessage {
                Text(message).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(40)
        .frame(minWidth: 320, minHeight: 240)
    }
}
