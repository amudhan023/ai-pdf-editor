import SwiftUI
import PDFEngineAPI

/// Document outline (bookmark/TOC) tree. Entries with a destination navigate
/// on click; purely structural headings (no page target) just disclose their
/// children. Nested nodes render via `OutlineGroup` disclosure rows.
struct OutlineSidebarView: View {
    @ObservedObject var viewModel: DocumentViewModel

    var body: some View {
        if viewModel.outline.isEmpty {
            ContentUnavailableView(
                "No Outline",
                systemImage: "list.bullet.indent",
                description: Text("This document has no table of contents.")
            )
        } else {
            List {
                OutlineGroup(viewModel.outline, children: \.disclosureChildren) { node in
                    OutlineRow(node: node, viewModel: viewModel)
                }
            }
            .listStyle(.sidebar)
        }
    }
}

private struct OutlineRow: View {
    let node: OutlineNode
    let viewModel: DocumentViewModel

    var body: some View {
        if let destination = node.destinationPage {
            Button {
                viewModel.navigate(to: destination, zoom: node.zoom)
            } label: {
                Text(node.title)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
        } else {
            Text(node.title)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
    }
}

extension OutlineNode {
    /// `OutlineGroup` treats `nil` children as a leaf (no disclosure
    /// chevron); the API type uses an empty array for leaves.
    var disclosureChildren: [OutlineNode]? {
        children.isEmpty ? nil : children
    }
}
