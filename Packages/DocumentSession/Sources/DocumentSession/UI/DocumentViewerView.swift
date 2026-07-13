import SwiftUI
import PDFEngineAPI

/// Minimal vertically-scrolling page view (P0-07 v1 scope): naive
/// one-tile-per-page rendering, no viewport-driven tiling/prefetch — that's
/// P1-01's real tiling task. Renders whatever `DocumentViewModel.state` says.
public struct DocumentViewerView: View {
    @ObservedObject private var viewModel: DocumentViewModel

    public init(viewModel: DocumentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        switch viewModel.state {
        case .empty:
            ContentUnavailableView("No Document Open", systemImage: "doc")
        case .loading:
            ProgressView("Opening…")
        case .failed(let error):
            ContentUnavailableView(
                "Couldn't Open Document",
                systemImage: "exclamationmark.triangle",
                description: Text(error.debugDescriptionForDisplay)
            )
        case .loaded(let pageCount):
            ScrollView(.vertical) {
                LazyVStack(spacing: 16) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        PageView(viewModel: viewModel, page: PageIndex(index))
                    }
                }
                .padding()
            }
        }
    }
}

private struct PageView: View {
    let viewModel: DocumentViewModel
    let page: PageIndex

    @State private var image: PageImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image.makeNSImage())
                    .resizable()
                    .aspectRatio(image.pointSize.width / image.pointSize.height, contentMode: .fit)
            } else {
                Color(nsColor: .textBackgroundColor)
                    .aspectRatio(1 / 1.294, contentMode: .fit)
            }
        }
        .shadow(radius: 2)
        .task {
            image = await viewModel.pageImage(page: page, scale: 1.0)
        }
    }
}

private extension DocumentSessionError {
    /// Product-facing text is normally a localized lookup keyed by
    /// `userMessageKey`; the raw description here stands in until the
    /// localization catalog exists (out of scope for this task).
    var debugDescriptionForDisplay: String { userMessageKey }
}
