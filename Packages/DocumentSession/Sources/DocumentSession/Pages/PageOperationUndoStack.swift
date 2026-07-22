import PDFEngineAPI

/// Records page-structural ops as invertible changes so `DocumentSession`
/// can undo/redo, mirroring `AnnotationUndoStack`'s shape (P1-04): pure
/// value-type logic, no engine access — `DocumentSession` turns a `Change`
/// back into a `PageOrganizer.apply` call.
///
/// **`.deleted` has no undo support in this version.** Undoing a delete
/// needs the deleted page's content preserved somewhere before the delete
/// happens (a "trash" document), but creating one needs a blank/empty
/// `DocumentHandle` — a capability nothing reachable from this package
/// exposes: `PDFEngineAPI.DocumentLifecycle` only opens a document from an
/// existing file `URL`, never creates one from nothing. Hand-rolling raw
/// blank-PDF bytes in this package to work around it would be exactly the
/// kind of fragile, unreviewed shortcut CLAUDE.md §3.7 exists to prevent —
/// this needs either a new `DocumentLifecycle`/creation capability (a
/// frozen-seam ADR decision, not this task's call to make unilaterally) or
/// a different design, flagged in the task Journal for follow-up rather
/// than worked around here. `insert`/`reorder`/`rotate` need no such
/// capability (their inverse is expressible with data already at hand) and
/// are fully undoable.
public struct PageOperationUndoStack: Sendable {
    public enum Change: Sendable, Equatable {
        /// The full forward `.insert` parameters — needed for redo (a
        /// duplicate's redo must re-run the same insert, not just "delete
        /// then somehow come back").
        case inserted(from: DocumentHandle, sourcePage: PageIndex, at: PageIndex)
        case reordered(from: PageIndex, to: PageIndex)
        case rotated(PageIndex, from: PageRotation, to: PageRotation)
    }

    private var undoStack: [Change] = []
    private var redoStack: [Change] = []

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call after successfully performing `change` against the engine.
    /// Discards redo history, same contract as `AnnotationUndoStack`.
    public mutating func record(_ change: Change) {
        undoStack.append(change)
        redoStack.removeAll()
    }

    /// Call after an operation this stack can't itself represent (a
    /// `.delete`, which has no undo support — see this type's header doc).
    /// A delete shifts every later page's index, which can silently
    /// invalidate an already-recorded `Change`'s `PageIndex`es — undoing a
    /// stale entry after that could throw (if the index is now
    /// out-of-range) or, worse, silently act on the *wrong* page if a
    /// coincidentally-valid index still exists. Clearing all history is the
    /// conservative-safe response, same principle `record()` already
    /// applies to the redo stack when a fresh action arrives.
    public mutating func invalidateHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Pops the most recent change and returns the `PageOperation` to
    /// *perform* to undo it.
    public mutating func undo() -> PageOperation? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        return Self.inverseOperation(of: change)
    }

    /// Pops the most recently undone change and returns the `PageOperation`
    /// to *perform* to redo it (the original forward operation).
    public mutating func redo() -> PageOperation? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        return Self.forwardOperation(of: change)
    }

    private static func forwardOperation(of change: Change) -> PageOperation {
        switch change {
        case .inserted(let from, let sourcePage, let at):
            .insert(from: from, sourcePage: sourcePage, at: at)
        case .reordered(let from, let to):
            .reorder(from: from, to: to)
        case .rotated(let page, _, let to):
            .rotate(page, by: to)
        }
    }

    private static func inverseOperation(of change: Change) -> PageOperation {
        switch change {
        case .inserted(_, _, let at):
            .delete(at)
        case .reordered(let from, let to):
            // Same-length move: undoing "from -> to" is exactly "to -> from"
            // (DocEngineHost's PageOrganizer conformance clamps `to` the
            // same way for both directions since page count never changes
            // across a reorder).
            .reorder(from: to, to: from)
        case .rotated(let page, let from, _):
            .rotate(page, by: from)
        }
    }
}
