import PDFEngineAPI

/// Multi-select state for the thumbnail sidebar, with macOS list semantics:
/// plain click selects one, ⌘-click toggles, ⇧-click extends a contiguous
/// range from the last anchor. Pure value type so the semantics are unit-
/// testable without any view in the loop.
///
/// Identity note for P1-06 (drag-reorder consumer): selection is keyed by
/// `PageIndex`, which is *positional* — after a reorder/delete the caller must
/// remap or `clear()` the selection, because index N now names a different
/// page. If P1-06 needs selection to survive reorder, it should introduce a
/// stable per-page identity at the engine seam and migrate this model to it.
public struct ThumbnailSelectionModel: Equatable, Sendable {
    public private(set) var selectedPages: Set<PageIndex> = []
    private var anchor: PageIndex?

    public init() {}

    public func isSelected(_ page: PageIndex) -> Bool {
        selectedPages.contains(page)
    }

    /// Plain click: single selection, page becomes the range anchor.
    public mutating func select(_ page: PageIndex) {
        selectedPages = [page]
        anchor = page
    }

    /// ⌘-click: toggle membership. A newly added page becomes the anchor;
    /// removing the anchor page leaves the anchor on any remaining selected
    /// page (lowest index) so a following ⇧-click still has a range origin.
    public mutating func toggle(_ page: PageIndex) {
        if selectedPages.contains(page) {
            selectedPages.remove(page)
            if anchor == page {
                anchor = selectedPages.min()
            }
        } else {
            selectedPages.insert(page)
            anchor = page
        }
    }

    /// ⇧-click: replace the selection with the contiguous range between the
    /// anchor and `page` (inclusive, either direction). With no anchor yet it
    /// behaves as a plain click.
    public mutating func extend(to page: PageIndex) {
        guard let anchor else {
            select(page)
            return
        }
        let low = Swift.min(anchor.value, page.value)
        let high = Swift.max(anchor.value, page.value)
        selectedPages = Set((low...high).map { PageIndex($0) })
    }

    public mutating func clear() {
        selectedPages = []
        anchor = nil
    }
}
