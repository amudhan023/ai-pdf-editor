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
    @StateObject private var search: SearchViewModel
    @StateObject private var markup: MarkupToolbarViewModel
    let pageCount: Int

    @State private var viewportSize: CGSize = .zero
    @State private var didRestoreScroll = false
    @State private var referenceMetadata: PageMetadata?
    @State private var showSidebar = true
    @GestureState private var pinchMagnification: Double = 1.0

    init(viewModel: DocumentViewModel, pageCount: Int) {
        self.viewModel = viewModel
        self.pageCount = pageCount
        _search = StateObject(wrappedValue: viewModel.makeSearchViewModel())
        _markup = StateObject(wrappedValue: viewModel.makeMarkupToolbarViewModel())
    }

    private var markupPage: PageIndex { viewModel.currentPage ?? PageIndex(0) }

    var body: some View {
        VStack(spacing: 0) {
            zoomToolbar
            markupToolbar
            HSplitView {
                if showSidebar {
                    DocumentSidebarView(viewModel: viewModel, pageCount: pageCount)
                        .frame(minWidth: 140, idealWidth: 180, maxWidth: 280)
                }
                pageScroller
            }
        }
        .gesture(
            MagnificationGesture()
                .updating($pinchMagnification) { value, state, _ in state = value }
                .onEnded { value in applyZoomFactor(value) }
        )
    }

    /// "Mark Selection" turns the active search hit's run into a markup
    /// annotation — the documented scope cut for creation (see
    /// `MarkupToolbarViewModel`'s doc comment): there's no drag-to-select
    /// gesture in the viewer yet, so a pre-extracted `TextRun` (here, the
    /// current search result's run) is the caller-supplied target.
    private var markupToolbar: some View {
        HStack(spacing: 12) {
            MarkupToolbarView(markup: markup, page: markupPage)
            Button("Mark Selection") {
                guard let result = search.currentResult else { return }
                let run = TextRun(id: result.runID, page: result.page, text: result.snippet, boundingBox: result.boundingBox, fontSize: 0)
                Task { await markup.createMarkup(on: run) }
            }
            .disabled(search.currentResult == nil)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var pageScroller: some View {
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
                                searchHighlights: search.highlightsByPage[PageIndex(index)] ?? [],
                                annotations: markup.annotationsByPage[PageIndex(index)] ?? [],
                                selectedAnnotationID: markup.selectedAnnotationID,
                                onSelectAnnotation: { markup.selectAnnotation($0) },
                                onMetadata: { referenceMetadata = referenceMetadata ?? $0 }
                            )
                            .task(id: index) { await markup.loadAnnotations(page: PageIndex(index)) }
                            .id(index)
                            .onAppear { viewModel.pageDidBecomeVisible(PageIndex(index)) }
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
                .onChange(of: viewModel.navigationTarget) { _, target in
                    guard let target else { return }
                    scrollProxy.scrollTo(target.page.value, anchor: .top)
                }
            }
        }
    }

    private var zoomToolbar: some View {
        HStack(spacing: 12) {
            Button {
                showSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
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
            SearchBarView(search: search)
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
