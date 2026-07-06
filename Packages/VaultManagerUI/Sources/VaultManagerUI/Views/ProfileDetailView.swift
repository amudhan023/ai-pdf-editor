import SwiftUI
import VaultAPI

public struct ProfileDetailView: View {
    @ObservedObject private var viewModel: ProfileDetailViewModel
    private let pasteboard: TransientPasteboardWriter
    private let sections: [FieldSection]

    public init(
        viewModel: ProfileDetailViewModel,
        sections: [FieldSection] = [.identity, .contact, .employment, .financial],
        pasteboard: TransientPasteboardWriter = TransientPasteboardWriter()
    ) {
        self.viewModel = viewModel
        self.sections = sections
        self.pasteboard = pasteboard
    }

    public var body: some View {
        Form {
            ForEach(sections, id: \.self) { section in
                Section(sectionTitle(section)) {
                    ForEach(FieldCatalog.entries(for: section), id: \.path) { entry in
                        ProfileFieldRowView(
                            label: entry.label, path: entry.path, viewModel: viewModel, pasteboard: pasteboard
                        )
                    }
                }
            }
        }
        .task {
            let allPaths = sections.flatMap { FieldCatalog.entries(for: $0).map(\.path) }
            await viewModel.load(catalog: allPaths)
        }
    }

    private func sectionTitle(_ section: FieldSection) -> String {
        switch section {
        case .identity: "Identity"
        case .contact: "Contact"
        case .employment: "Employment"
        case .education: "Education"
        case .family: "Family"
        case .financial: "Financial"
        case .health: "Health"
        case .licenses: "Licenses"
        case .travel: "Travel"
        case .custom: "Custom"
        }
    }
}
