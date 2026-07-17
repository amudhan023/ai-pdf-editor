import SwiftUI
import PDFEngineAPI

/// Virtualized page-thumbnail list: `LazyVStack` materializes only the rows
/// in/near the visible range, and each row fetches one low-res full-page
/// tile through the shared cache-first path. The tile scale deliberately
/// matches `PageTileView`'s placeholder scale so a thumbnail and the main
/// view's placeholder for the same page are one cache entry, not two.
struct ThumbnailSidebarView: View {
    @ObservedObject var viewModel: DocumentViewModel
    let pageCount: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 10) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        ThumbnailCell(viewModel: viewModel, page: PageIndex(index))
                            .id(index)
                    }
                }
                .padding(8)
            }
            .onChange(of: viewModel.currentPage) { _, current in
                guard let current else { return }
                proxy.scrollTo(current.value, anchor: .center)
            }
        }
    }
}

private struct ThumbnailCell: View {
    @ObservedObject var viewModel: DocumentViewModel
    let page: PageIndex

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color(nsColor: .textBackgroundColor)
                        .aspectRatio(1 / 1.294, contentMode: .fit)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor, lineWidth: isHighlighted ? 3 : 1)
            )
            Text("\(page.value + 1)")
                .font(.caption)
                .foregroundStyle(viewModel.currentPage == page ? Color.accentColor : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .task { await loadThumbnail() }
    }

    private var isHighlighted: Bool {
        viewModel.thumbnailSelection.isSelected(page) || viewModel.currentPage == page
    }

    private var borderColor: Color {
        isHighlighted ? Color.accentColor : Color(nsColor: .separatorColor)
    }

    /// SwiftUI's `TapGesture.modifiers` requires the modifier to be *held*
    /// for the gesture to fire at all, which makes plain-click vs ⌘/⇧-click
    /// three competing gestures; reading the current event's flags keeps it
    /// one gesture with one dispatch point.
    private func handleTap() {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        if modifiers.contains(.shift) {
            viewModel.thumbnailSelection.extend(to: page)
        } else if modifiers.contains(.command) {
            viewModel.thumbnailSelection.toggle(page)
        } else {
            viewModel.thumbnailSelection.select(page)
            viewModel.navigate(to: page)
        }
    }

    private func loadThumbnail() async {
        guard image == nil, let metadata = await viewModel.metadata(page: page) else { return }
        let fullPageRect = PDFRect(x: 0, y: 0, width: metadata.size.width, height: metadata.size.height)
        if let tile = await viewModel.tile(page: page, tileRect: fullPageRect, scale: 0.15) {
            image = tile.makeNSImage()
        }
    }
}
