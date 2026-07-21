import SwiftUI
import VaultAPI

/// A selected person's whole detail pane: fields grouped by `FieldSection`,
/// manual/custom-field entry, and every history category. `needsReauth`
/// surfaces `VaultUnlockViewModel`'s re-auth affordance inline rather than
/// as a separate error, per `ProfileDetailViewModel.reveal`'s contract.
public struct SectionDetailView: View {
    @ObservedObject var viewModel: ProfileDetailViewModel
    let onReauth: () -> Void

    public init(viewModel: ProfileDetailViewModel, onReauth: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onReauth = onReauth
    }

    private var fieldsBySection: [FieldSection: [DisplayField]] {
        Dictionary(grouping: viewModel.fields.values, by: { $0.path.section })
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.needsReauth {
                    HStack {
                        Text("Re-authentication required to reveal this field.")
                        Button("Re-authenticate", action: onReauth)
                    }
                    .padding(8)
                    .background(.yellow.opacity(0.2))
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }

                ForEach(FieldSection.allCases, id: \.self) { section in
                    if let fields = fieldsBySection[section], !fields.isEmpty {
                        VStack(alignment: .leading) {
                            Text(section.rawValue.capitalized).font(.headline)
                            ForEach(fields) { field in
                                FieldRow(
                                    field: field,
                                    onReveal: { Task { await viewModel.reveal(field.path) } },
                                    onMask: { viewModel.mask(field.path) },
                                    onCopy: { viewModel.copyRevealedValueToPasteboard($0) },
                                    onDelete: { Task { await viewModel.deleteField(field.path) } }
                                )
                            }
                        }
                    }
                }

                Divider()
                Text("Add Field").font(.headline)
                NewFieldRow { path, value, sensitivity in
                    await viewModel.writeField(path: path, value: value, sensitivity: sensitivity)
                }

                Divider()
                ForEach(HistoryCategory.allCases, id: \.self) { category in
                    HistoryListSection(category: category, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}
