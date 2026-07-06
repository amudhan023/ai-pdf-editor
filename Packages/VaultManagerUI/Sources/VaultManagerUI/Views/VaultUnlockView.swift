import SwiftUI
import VaultAPI

public struct VaultUnlockView: View {
    @ObservedObject private var viewModel: VaultUnlockViewModel
    @State private var recoveryCode: String = ""
    @State private var showRecoveryCodeEntry = false

    public init(viewModel: VaultUnlockViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
            Text("Vault Locked")
                .font(.title2)

            if let error = viewModel.lastError {
                Text(message(for: error))
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Unlock with Touch ID") {
                Task { await viewModel.unlockWithBiometrics() }
            }
            .buttonStyle(.borderedProminent)

            Button(showRecoveryCodeEntry ? "Cancel" : "Use recovery code instead") {
                showRecoveryCodeEntry.toggle()
            }
            .buttonStyle(.plain)

            if showRecoveryCodeEntry {
                SecureField("Recovery code", text: $recoveryCode)
                    .textFieldStyle(.roundedBorder)
                Button("Unlock") {
                    Task { await viewModel.unlockWithRecoveryCode(recoveryCode) }
                }
                .disabled(recoveryCode.isEmpty)
            }
        }
        .padding(32)
        .task { await viewModel.refreshLockState() }
    }

    private func message(for error: VaultUnlockError) -> String {
        switch error {
        case .biometricsUnavailable: "Touch ID isn't available on this Mac."
        case .biometricsFailed: "Touch ID didn't match. Try again."
        case .invalidRecoveryCode: "That recovery code isn't valid."
        case .cancelled: "Unlock cancelled."
        }
    }
}
