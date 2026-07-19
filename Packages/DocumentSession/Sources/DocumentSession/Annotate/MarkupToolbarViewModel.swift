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
///
/// **P1-05 additions:** the picker's subtype set now also covers note
/// (`.text`), free text, square, circle, and stamp — all creatable from the
/// same `TextRun`-rect flow as text markup. `.ink` and `.link` are
/// deliberately **not** offered here even though the engine supports them
/// (`DocEngineHost`, ADR-015): ink needs a real freehand-stroke capture
/// gesture (none exists in the viewer yet) and a rect-only ink annotation
/// would be an invisible, empty `/InkList`; a toolbar-placed link has no
/// meaningful URI to attach and PDFium can't set one anyway (ADR-015). Both
/// remain fully engine/session-tested, just not toolbar-reachable this pass
/// — see `tasks/escalations/E-010-p1-05-line-annotations-unsupported.md`
/// for the full accounting of what P1-05 did and didn't wire into the UI.
@MainActor
public final class MarkupToolbarViewModel: ObservableObject {
    /// Subtypes offered by this toolbar's picker (see the type doc comment
    /// for what's deliberately excluded and why).
    public static let pickerSubtypes: [AnnotationSubtype] = [
        .highlight, .underline, .strikeOut, .squiggly, .text, .freeText, .square, .circle, .stamp
    ]

    /// Subtypes whose creation needs `/QuadPoints` (text markup + link) —
    /// everything else uses `boundingBox` alone (ADR-014/ADR-015).
    private static let quadSubtypes: Set<AnnotationSubtype> = [.highlight, .underline, .strikeOut, .squiggly, .link]

    @Published public private(set) var annotationsByPage: [PageIndex: [Annotation]] = [:]
    @Published public var selectedSubtype: AnnotationSubtype = .highlight
    @Published public var selectedColor = AnnotationColor(red: 1, green: 0.92, blue: 0.2)
    @Published public var selectedOpacity: Double = 1.0
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

    /// Creates an annotation of `selectedSubtype` covering `run`'s bounding
    /// box, using `selectedColor`/`selectedOpacity`. Quad-bearing subtypes
    /// (text markup) get `run.boundingBox` as a single quad; every other
    /// subtype (note, free text, square, circle, stamp) uses the bounding
    /// box alone — see the type doc comment for the full subtype/gesture
    /// scope cut.
    public func createMarkup(on run: TextRun) async {
        let quads: [PDFQuad] = Self.quadSubtypes.contains(selectedSubtype) ? [
            PDFQuad(
                topLeft: PDFPoint(x: run.boundingBox.origin.x, y: run.boundingBox.origin.y + run.boundingBox.height),
                topRight: PDFPoint(x: run.boundingBox.origin.x + run.boundingBox.width, y: run.boundingBox.origin.y + run.boundingBox.height),
                bottomLeft: PDFPoint(x: run.boundingBox.origin.x, y: run.boundingBox.origin.y),
                bottomRight: PDFPoint(x: run.boundingBox.origin.x + run.boundingBox.width, y: run.boundingBox.origin.y)
            )
        ] : []
        let annotation = Annotation(
            page: run.page,
            subtype: selectedSubtype,
            boundingBox: run.boundingBox,
            color: selectedColor,
            quadPoints: quads,
            opacity: selectedOpacity,
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
