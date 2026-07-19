import Foundation
import PDFEngineAPI

/// Text-markup creation/edit/delete state for the viewer toolbar (P1-04).
///
/// **Scope cut, documented in the PR:** creation targets a single already-
/// extracted `TextRun` (P1-03's per-run geometry) rather than an arbitrary
/// multi-run drag selection — there's no drag-to-select gesture in the
/// viewer yet (P1-03 built search highlighting over existing runs, not
/// interactive text selection). A caller-supplied `TextRun` still exercises
/// the full engine contract (quad points, color, opacity) end-to-end;
/// wiring a real multi-run drag gesture is follow-up UI work, not a
/// blocker for the underlying store.
@MainActor
public final class MarkupToolbarViewModel: ObservableObject {
    @Published public private(set) var annotationsByPage: [PageIndex: [Annotation]] = [:]
    @Published public var selectedSubtype: AnnotationSubtype = .highlight
    @Published public var selectedColor = AnnotationColor(red: 1, green: 0.92, blue: 0.2)
    @Published public private(set) var selectedAnnotationID: Annotation.ID?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false
    @Published public private(set) var lastError: DocumentSessionError?

    private let session: DocumentSession

    public init(session: DocumentSession) {
        self.session = session
    }

    public func loadAnnotations(page: PageIndex) async {
        do {
            annotationsByPage[page] = try await session.annotations(page: page)
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
        await refreshUndoRedoState()
    }

    /// Creates a markup annotation covering `run`'s bounding box as a
    /// single quad, using `selectedSubtype`/`selectedColor`.
    public func createMarkup(on run: TextRun) async {
        let quad = PDFQuad(
            topLeft: PDFPoint(x: run.boundingBox.origin.x, y: run.boundingBox.origin.y + run.boundingBox.height),
            topRight: PDFPoint(x: run.boundingBox.origin.x + run.boundingBox.width, y: run.boundingBox.origin.y + run.boundingBox.height),
            bottomLeft: PDFPoint(x: run.boundingBox.origin.x, y: run.boundingBox.origin.y),
            bottomRight: PDFPoint(x: run.boundingBox.origin.x + run.boundingBox.width, y: run.boundingBox.origin.y)
        )
        let annotation = Annotation(
            page: run.page,
            subtype: selectedSubtype,
            boundingBox: run.boundingBox,
            color: selectedColor,
            quadPoints: [quad],
            createdAt: Date()
        )
        do {
            try await session.addAnnotation(annotation)
            await loadAnnotations(page: run.page)
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func selectAnnotation(_ id: Annotation.ID?) {
        selectedAnnotationID = id
    }

    public func deleteSelected(page: PageIndex) async {
        guard let id = selectedAnnotationID else { return }
        do {
            try await session.removeAnnotation(id, page: page)
            selectedAnnotationID = nil
            await loadAnnotations(page: page)
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func undo(page: PageIndex) async {
        do {
            _ = try await session.undoAnnotation()
            await loadAnnotations(page: page)
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    public func redo(page: PageIndex) async {
        do {
            _ = try await session.redoAnnotation()
            await loadAnnotations(page: page)
        } catch let error as DocumentSessionError {
            lastError = error
        } catch {
            lastError = nil
        }
    }

    private func refreshUndoRedoState() async {
        canUndo = await session.canUndoAnnotation
        canRedo = await session.canRedoAnnotation
    }
}
