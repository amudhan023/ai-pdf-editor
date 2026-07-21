import SwiftUI

/// Sidebar container: segmented switch between the thumbnail list and the
/// outline tree. Owned by `DocumentViewerView`'s loaded state; both panes
/// drive navigation through the same `DocumentViewModel`.
public struct DocumentSidebarView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case thumbnails = "Pages"
        case outline = "Outline"
        case comments = "Comments"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: DocumentViewModel
    @StateObject private var comments: CommentSidebarViewModel
    let pageCount: Int

    @State private var pane: Pane = .thumbnails

    public init(viewModel: DocumentViewModel, pageCount: Int) {
        self.viewModel = viewModel
        self.pageCount = pageCount
        _comments = StateObject(wrappedValue: viewModel.makeCommentSidebarViewModel())
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Sidebar Pane", selection: $pane) {
                ForEach(Pane.allCases) { pane in
                    Text(pane.rawValue).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)
            Divider()
            switch pane {
            case .thumbnails:
                ThumbnailSidebarView(viewModel: viewModel, pageCount: pageCount)
            case .outline:
                OutlineSidebarView(viewModel: viewModel)
            case .comments:
                CommentSidebarView(comments: comments)
            }
        }
    }
}
