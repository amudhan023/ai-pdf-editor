import SwiftUI
import VaultAPI

/// Manual field entry: pick a section, a dot-path suffix under it, a kind,
/// then the typed value. Also how custom fields get created — pick section
/// `.custom` and the path becomes `custom.<suffix>` via `FieldPath.custom(_:)`.
struct NewFieldRow: View {
    let onAdd: (FieldPath, FieldValue, SensitivityTier) async -> Void

    @State private var section: FieldSection = .identity
    @State private var suffix = ""
    @State private var kind: FieldValueKind = .string
    @State private var draft: FieldValue = .string(SecureBytes(utf8: ""))
    @State private var sensitivity: SensitivityTier = .standard
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Section", selection: $section) {
                    ForEach(FieldSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                TextField("path.suffix", text: $suffix)
                Picker("Kind", selection: $kind) {
                    ForEach(FieldValueKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: kind) { draft = Self.emptyValue(for: kind) }
                Picker("Sensitivity", selection: $sensitivity) {
                    ForEach(SensitivityTier.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            FieldValueEditor(value: $draft)
            HStack {
                Button("Add Field") { Task { await submit() } }
                    .disabled(suffix.isEmpty)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        do {
            let segments = suffix.split(separator: ".").map(String.init)
            let path = section == .custom
                ? try FieldPath.custom(segments)
                : try FieldPath(validating: ([section.rawValue] + segments).joined(separator: "."))
            await onAdd(path, draft, sensitivity)
            suffix = ""
        } catch {
            errorMessage = "\(error)"
        }
    }

    private static func emptyValue(for kind: FieldValueKind) -> FieldValue {
        switch kind {
        case .string: .string(SecureBytes(utf8: ""))
        case .date: .date(Date())
        case .number: .number(0)
        case .enumeration: .enumeration("")
        case .list: .list([])
        }
    }
}
