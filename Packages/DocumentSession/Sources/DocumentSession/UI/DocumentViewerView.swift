import SwiftUI
import PDFEngineAPI

/// Continuous-scroll document view: real per-page tiling (`PageTileView`)
/// plus zoom (fit-width/fit-page/custom, keyboard/menu/pinch) and page-level
/// scroll position restoration. Replaces P0-07's one-tile-per-page view.
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
            LoadedDocumentView(viewModel: viewModel, pageCount: pageCount)
        }
    }
}

private struct LoadedDocumentView: View {
    @ObservedObject var viewModel: DocumentViewModel
    let pageCount: Int

    @State private var viewportSize: CGSize = .zero
    @State private var didRestoreScroll = false
    @State private var referenceMetadata: PageMetadata?
    @GestureState private var pinchMagnification: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            zoomToolbar
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 16) {
                            ForEach(0..<pageCount, id: \.self) { index in
                                PageTileView(
                                    viewModel: viewModel,
                                    page: PageIndex(index),
                                    zoomMode: viewModel.zoomMode,
                                    viewportSize: proxy.size,
                                    onMetadata: { referenceMetadata = referenceMetadata ?? $0 }
                                )
                                .id(index)
                                .onAppear { recordScrollPosition(page: index) }
                            }
                        }
                        .padding()
                        .scaleEffect(pinchMagnification)
                    }
                    .onAppear {
                        viewportSize = proxy.size
                        restoreScrollIfNeeded(scrollProxy: scrollProxy)
                    }
                    .onChange(of: proxy.size) { _, newValue in viewportSize = newValue }
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .updating($pinchMagnification) { value, state, _ in state = value }
                .onEnded { value in applyZoomFactor(value) }
        )
    }

    private var zoomToolbar: some View {
        HStack(spacing: 12) {
            Button("Fit Width") { viewModel.setZoomMode(.fitWidth) }
            Button("Fit Page") { viewModel.setZoomMode(.fitPage) }
            Button {
                applyZoomFactor(0.8)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .keyboardShortcut("-", modifiers: .command)
            Button {
                applyZoomFactor(1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .keyboardShortcut("+", modifiers: .command)
            Button("100%") { viewModel.setZoomMode(.custom(1.0)) }
                .keyboardShortcut("0", modifiers: .command)
            Spacer()
        }
        .padding(8)
    }

    private func applyZoomFactor(_ factor: Double) {
        viewModel.setZoomMode(.custom(ZoomMath.clamp(currentScale() * factor)))
    }

    private func currentScale() -> Double {
        guard let referenceMetadata else { return 1.0 }
        return ZoomMath.scale(
            for: viewModel.zoomMode,
            pageSize: referenceMetadata.size,
            viewportSize: (Double(viewportSize.width), Double(viewportSize.height))
        )
    }

    /// Page-granularity scroll restoration: the last page whose tile view
    /// entered the lazily-rendered range is recorded as "current." Within-
    /// page vertical fraction isn't tracked (always 0 / page top) — precise
    /// sub-page offset tracking needs continuous scroll-geometry plumbing
    /// SwiftUI's `ScrollView` doesn't expose without an AppKit bridge, which
    /// is out of this pass's scope.
    private func recordScrollPosition(page: Int) {
        viewModel.recordScrollPosition(ScrollPosition(page: page, verticalFraction: 0))
    }

    private func restoreScrollIfNeeded(scrollProxy: ScrollViewProxy) {
        guard !didRestoreScroll, let restored = viewModel.restoredScrollPosition else { return }
        didRestoreScroll = true
        scrollProxy.scrollTo(restored.page, anchor: .top)
    }
}

private extension DocumentSessionError {
    /// Product-facing text is normally a localized lookup keyed by
    /// `userMessageKey`; the raw description here stands in until the
    /// localization catalog exists (out of scope for this task).
    var debugDescriptionForDisplay: String { userMessageKey }
}
