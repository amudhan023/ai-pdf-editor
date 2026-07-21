import SwiftUI

/// One-time recovery-code display ceremony. `dismiss` is the caller's
/// signal to close the sheet — the code itself is never re-shown after
/// (`VaultUnlockViewModel.recoveryCode` is cleared on dismiss, and
/// `RecoveryCodeProviding.revealOnce()` refuses a second reveal regardless).
public struct RecoveryCodeRevealView: View {
    let code: String
    let dismiss: () -> Void

    public init(code: String, dismiss: @escaping () -> Void) {
        self.code = code
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Recovery Code").font(.title2)
            Text("Write this down and store it somewhere safe. It will not be shown again.")
                .font(.caption)
                .multilineTextAlignment(.center)
            Text(code)
                .font(.system(.title3, design: .monospaced))
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("I've saved it", action: dismiss)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(minWidth: 360)
    }
}
