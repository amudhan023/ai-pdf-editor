import SwiftUI
import VaultAPI

/// One field line: masked placeholder + reveal button for `.sensitive`
/// fields, plain value otherwise. Copy button only appears once revealed —
/// there is no path to copy an unrevealed value (`ProfileDetailViewModel`
/// only ever holds plaintext for a field the user explicitly revealed).
struct FieldRow: View {
    let field: DisplayField
    let onReveal: () -> Void
    let onMask: () -> Void
    let onCopy: (FieldValue) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(field.path.description).font(.system(.body, design: .monospaced))
            Spacer()
            if field.isMasked {
                Text("••••••••")
                Button("Reveal", action: onReveal)
            } else if let value = field.revealedValue {
                Text(displayString(for: value))
                if field.sensitivity == .sensitive {
                    Button("Copy") { onCopy(value) }
                    Button("Hide", action: onMask)
                }
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
    }

    private func displayString(for value: FieldValue) -> String {
        switch value {
        case .string(let bytes): bytes.exposeAsPlaintext()
        case .date(let date): date.formatted(date: .abbreviated, time: .omitted)
        case .number(let number): String(number)
        case .enumeration(let raw): raw
        case .list(let items): "[\(items.count) items]"
        }
    }
}
