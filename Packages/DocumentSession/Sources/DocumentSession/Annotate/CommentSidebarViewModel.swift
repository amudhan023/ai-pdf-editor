import Foundation
import PDFEngineAPI

/// Comment-list sidebar state for note (`.text`) annotations (P1-05).
///
/// The task's "note popups and comment list sidebar" requirement splits into
/// two halves: an in-page popup for a single note (already covered by
/// `PageTileView`'s existing annotation selection/overlay — clicking a note
/// annotation selects it the same way any other markup does) and this
/// document-wide list, which is what this view model provides. **Scope cut,
/// documented here:** v1 is reply-free (per the task's own "reply-free v1"
/// wording) — `contents`/`author`/`modifiedAt` are shown, but there is no
/// threaded-reply model in `PDFEngineAPI` to build on.
@MainActor
public final class CommentSidebarViewModel: ObservableObject {
    @Published public private(set) var comments: [Annotation] = []
    @Published public private(set) var lastError: DocumentSessionError?

    private let session: DocumentSession
    private let onNavigate: (PageIndex) -> Void

    public init(session: DocumentSession, onNavigate: @escaping (PageIndex) -> Void) {
        self.session = session
        self.onNavigate = onNavigate
    }

    /// Reloads every `.text`-subtype annotation across the whole document,
    /// ordered by page then creation time. A failed per-page read degrades
    /// that page to "no comments" rather than failing the whole reload —
    /// same degradation contract as `DocumentViewModel.loadOutline`.
    public func reload() async {
        do {
            let pageCount = try await session.pageCount()
            var all: [Annotation] = []
            for index in 0..<pageCount {
                let page = PageIndex(index)
                if let pageAnnotations = try? await session.annotations(page: page) {
                    all.append(contentsOf: pageAnnotations.filter { $0.subtype == .text })
                }
            }
            comments = all.sorted { lhs, rhs in
                if lhs.page.value != rhs.page.value { return lhs.page.value < rhs.page.value }
                return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            }
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func select(_ comment: Annotation) {
        onNavigate(comment.page)
    }

    public func delete(_ comment: Annotation) async {
        do {
            try await session.removeAnnotation(comment.id, page: comment.page)
            await reload()
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }
}
