import SwiftUI
import VaultAPI

/// Typed editor for one `FieldValue`, dispatching on its kind (PRD FR-2.2:
/// "type (string/date/number/enum/list)"). `enumOptions` only matters for
/// `.enumeration` — callers without a fixed option set (custom fields) pass
/// `[]` and get a free-text field instead of a picker.
public struct FieldValueEditor: View {
    @Binding var value: FieldValue
    let enumOptions: [String]

    public init(value: Binding<FieldValue>, enumOptions: [String] = []) {
        self._value = value
        self.enumOptions = enumOptions
    }

    public var body: some View {
        switch value {
        case .string(let bytes):
            TextField("Value", text: Binding(
                get: { bytes.exposeAsPlaintext() },
                set: { value = .string(SecureBytes(utf8: $0)) }
            ))
        case .date(let date):
            DatePicker("Value", selection: Binding(
                get: { date },
                set: { value = .date($0) }
            ), displayedComponents: .date)
        case .number(let number):
            TextField("Value", value: Binding(
                get: { number },
                set: { value = .number($0) }
            ), format: .number)
        case .enumeration(let raw) where !enumOptions.isEmpty:
            Picker("Value", selection: Binding(
                get: { raw },
                set: { value = .enumeration($0) }
            )) {
                ForEach(enumOptions, id: \.self) { Text($0).tag($0) }
            }
        case .enumeration(let raw):
            TextField("Value", text: Binding(
                get: { raw },
                set: { value = .enumeration($0) }
            ))
        case .list(let items):
            ListValueEditor(items: Binding(
                get: { items },
                set: { value = .list($0) }
            ))
        }
    }
}

/// A list value edited as free-text entries — the only shape this UI needs
/// today (PRD examples are all string lists, e.g. "prior addresses' aliases").
/// Nested non-string list items aren't editable here; document as a scope
/// cut rather than building a recursive editor nothing asks for yet.
private struct ListValueEditor: View {
    @Binding var items: [FieldValue]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(items.indices, id: \.self) { index in
                HStack {
                    TextField("Item", text: Binding(
                        get: { (try? items[index].asPlainString()) ?? "" },
                        set: { items[index] = .string(SecureBytes(utf8: $0)) }
                    ))
                    Button(role: .destructive) { items.remove(at: index) } label: {
                        Image(systemName: "minus.circle")
                    }
                }
            }
            Button("Add item") { items.append(.string(SecureBytes(utf8: ""))) }
        }
    }
}

private extension FieldValue {
    enum PlainStringError: Error { case notAString }
    func asPlainString() throws -> String {
        guard case .string(let bytes) = self else { throw PlainStringError.notAString }
        return bytes.exposeAsPlaintext()
    }
}
