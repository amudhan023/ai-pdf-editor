import SwiftUI
import UniformTypeIdentifiers
import DocumentSession

/// Composition-root view: wraps `DocumentSession`'s `DocumentViewerView`
/// with the app-chrome bits that are legitimately App/'s concern (open
/// affordances), not the package's — drag-and-drop target and the "Open…"
/// button, per this task's Requirements (dialog + drag-drop).
struct RootView: View {
    @ObservedObject var viewModel: DocumentViewModel
    let onOpen: () -> Void

    @State private var isDropTargeted = false

    var body: some View {
        DocumentViewerView(viewModel: viewModel)
            .frame(minWidth: 600, minHeight: 700)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Open…", action: onOpen)
                }
            }
            .overlay {
                if isDropTargeted {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 4)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                Task { await viewModel.open(url: url) }
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
    }
}
