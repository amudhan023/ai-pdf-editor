import SwiftUI
import PDFEngineAPI

/// One rendered tile positioned within its page, in SwiftUI view coordinates
/// (already scale- and axis-converted from PDF page-point space).
struct TileSlot: Identifiable {
    let id: String
    let rect: PDFRect
    let image: NSImage
}

/// Renders one page as a real tile grid (not one full-page bitmap): a cheap
/// low-res placeholder paints first, then each `TileGrid`-sized tile swaps
/// in as it resolves from `DocumentViewModel`'s cache-first tile fetch.
/// Re-tiles whenever `zoomMode` changes (a new scale invalidates every prior
/// tile's pixel content).
struct PageTileView: View {
    let viewModel: DocumentViewModel
    let page: PageIndex
    let zoomMode: ZoomMode
    let viewportSize: CGSize
    var searchHighlights: [PDFRect] = []
    var annotations: [Annotation] = []
    var selectedAnnotationID: Annotation.ID?
    var onSelectAnnotation: (Annotation.ID) -> Void = { _ in }
    let onMetadata: (PageMetadata) -> Void

    @State private var metadata: PageMetadata?
    @State private var placeholder: NSImage?
    @State private var tiles: [TileSlot] = []

    private var scale: Double {
        guard let metadata else { return 1.0 }
        return ZoomMath.scale(
            for: zoomMode,
            pageSize: metadata.size,
            viewportSize: (Double(viewportSize.width), Double(viewportSize.height))
        )
    }

    var body: some View {
        Group {
            if let metadata {
                ZStack(alignment: .topLeading) {
                    Color(nsColor: .textBackgroundColor)
                    if tiles.isEmpty, let placeholder {
                        Image(nsImage: placeholder)
                            .resizable()
                            .frame(width: metadata.size.width * scale, height: metadata.size.height * scale)
                    }
                    ForEach(tiles) { slot in
                        tileImage(slot, pageHeightPoints: metadata.size.height)
                    }
                    ForEach(Array(searchHighlights.enumerated()), id: \.offset) { _, rect in
                        highlightOverlay(rect, pageHeightPoints: metadata.size.height)
                    }
                    ForEach(annotations) { annotation in
                        annotationOverlay(annotation, pageHeightPoints: metadata.size.height)
                    }
                }
                .frame(width: metadata.size.width * scale, height: metadata.size.height * scale)
                .rotationEffect(.degrees(Double(metadata.rotation.rawValue)))
            } else {
                Color(nsColor: .textBackgroundColor)
                    .aspectRatio(1 / 1.294, contentMode: .fit)
            }
        }
        .shadow(radius: 2)
        .task(id: TaskKey(zoomMode: zoomMode, viewportSize: viewportSize)) {
            await load()
        }
    }

    private func tileImage(_ slot: TileSlot, pageHeightPoints: Double) -> some View {
        let width = slot.rect.width * scale
        let height = slot.rect.height * scale
        // PDF space has a bottom-left origin; SwiftUI's is top-left.
        let flippedY = pageHeightPoints - slot.rect.origin.y - slot.rect.height
        return Image(nsImage: slot.image)
            .resizable()
            .frame(width: width, height: height)
            .position(x: slot.rect.origin.x * scale + width / 2, y: flippedY * scale + height / 2)
    }

    /// Same page-point → view-coordinate transform as `tileImage` (scale +
    /// bottom-left → top-left Y flip), applied to a search hit's run box.
    private func highlightOverlay(_ rect: PDFRect, pageHeightPoints: Double) -> some View {
        let width = rect.width * scale
        let height = rect.height * scale
        let flippedY = pageHeightPoints - rect.origin.y - rect.height
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.yellow.opacity(0.35))
            .frame(width: width, height: height)
            .position(x: rect.origin.x * scale + width / 2, y: flippedY * scale + height / 2)
            .allowsHitTesting(false)
    }

    /// Click-to-select existing markup (P1-04): tapping a rendered
    /// annotation's box selects it in the toolbar, enabling delete — the
    /// documented substitute for a drag-select/resize-handle editor.
    private func annotationOverlay(_ annotation: Annotation, pageHeightPoints: Double) -> some View {
        let rect = annotation.boundingBox
        let width = rect.width * scale
        let height = rect.height * scale
        let flippedY = pageHeightPoints - rect.origin.y - rect.height
        let color = annotation.color.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? .yellow
        let isSelected = annotation.id == selectedAnnotationID
        return RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(annotation.opacity * 0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, lineWidth: isSelected ? 2 : 0)
            )
            .frame(width: width, height: height)
            .position(x: rect.origin.x * scale + width / 2, y: flippedY * scale + height / 2)
            .contentShape(Rectangle())
            .onTapGesture { onSelectAnnotation(annotation.id) }
    }

    private func load() async {
        let resolved: PageMetadata
        if let metadata {
            resolved = metadata
        } else if let fetched = await viewModel.metadata(page: page) {
            resolved = fetched
            metadata = fetched
            onMetadata(fetched)
        } else {
            return
        }

        let fullPageRect = PDFRect(x: 0, y: 0, width: resolved.size.width, height: resolved.size.height)

        if placeholder == nil {
            if let placeholderTile = await viewModel.tile(page: page, tileRect: fullPageRect, scale: 0.15) {
                placeholder = placeholderTile.makeNSImage()
            }
        }

        let rects = viewModel.tileRects(pageSize: resolved.size, visibleRect: fullPageRect, prefetchMargin: 0)
        var resolvedTiles: [TileSlot] = []
        resolvedTiles.reserveCapacity(rects.count)
        for rect in rects {
            guard let tile = await viewModel.tile(page: page, tileRect: rect, scale: scale) else { continue }
            resolvedTiles.append(TileSlot(id: "\(rect.origin.x)x\(rect.origin.y)@\(scale)", rect: rect, image: tile.makeNSImage()))
        }
        tiles = resolvedTiles
    }
}

private struct TaskKey: Equatable {
    let zoomMode: ZoomMode
    let viewportSize: CGSize
}
