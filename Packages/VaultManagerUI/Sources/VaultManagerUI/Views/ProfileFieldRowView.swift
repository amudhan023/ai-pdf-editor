import SwiftUI
import VaultAPI

/// One field row: label, masked/plain display, reveal/rehide toggle for
/// sensitive fields, and an editable text form that only bridges to
/// `SecureBytes`/`FieldValue` at submit time (CLAUDE.md §7.3's "bridge to
/// String only at the final UI/engine write").
struct ProfileFieldRowView: View {
    let label: String
    let path: FieldPath
    @ObservedObject var viewModel: ProfileDetailViewModel
    let pasteboard: TransientPasteboardWriter

    @State private var editText: String = ""
    @State private var isEditing = false

    private var state: FieldEditorState? { viewModel.fields[path] }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 160, alignment: .leading)

            if let state, state.isMasked {
                Text(state.isPresent ? "••••••••" : "Not set")
                    .foregroundStyle(.secondary)
                if state.isPresent {
                    Button("Reveal") { Task { await viewModel.reveal(path) } }
                        .buttonStyle(.link)
                }
            } else if let state, let value = state.revealedValue {
                Text(displayString(value))
                if state.sensitivity == .sensitive {
                    Button("Hide") { viewModel.rehide(path) }
                        .buttonStyle(.link)
                    Button("Copy") { pasteboard.copyTransiently(displayString(value)) }
                        .buttonStyle(.link)
                }
            } else {
                Text("Not set").foregroundStyle(.secondary)
            }

            Spacer()

            Button(isEditing ? "Cancel" : "Edit") {
                isEditing.toggle()
                if isEditing, let value = state?.revealedValue {
                    editText = displayString(value)
                }
            }
            .buttonStyle(.link)
        }
        .overlay(alignment: .bottom) {
            if viewModel.reauthRequired == path {
                Text("Re-authenticate to reveal this field.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .popover(isPresented: $isEditing) {
            VStack {
                TextField(label, text: $editText).textFieldStyle(.roundedBorder)
                Button("Save") {
                    let sensitivity = state?.sensitivity ?? .standard
                    Task {
                        await viewModel.writeValue(
                            path, value: .string(SecureBytes(utf8: editText)), sensitivity: sensitivity
                        )
                        isEditing = false
                    }
                }
            }
            .padding()
            .frame(minWidth: 240)
        }
    }

    private func displayString(_ value: FieldValue) -> String {
        switch value {
        case .string(let bytes): bytes.exposeAsPlaintext()
        case .date(let date): date.formatted(date: .abbreviated, time: .omitted)
        case .number(let number): String(number)
        case .enumeration(let raw): raw
        case .list(let values): values.map(displayString).joined(separator: ", ")
        }
    }
}
