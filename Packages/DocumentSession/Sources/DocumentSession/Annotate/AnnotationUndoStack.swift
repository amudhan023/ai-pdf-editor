import PDFEngineAPI

/// Records annotation CRUD as invertible changes so `DocumentSession` can
/// undo/redo. Pure value-type logic (no engine access) — `DocumentSession`
/// is the one that turns a `Change` back into an `AnnotationStore` call.
///
/// First undo primitive in this package (P1-04); intentionally scoped to
/// annotations rather than a fully generic multi-kind command stack —
/// extending to other mutation kinds (page ops, form fill, text edit) as
/// they land is future work, not preempted here.
public struct AnnotationUndoStack: Sendable {
    public enum Change: Sendable, Equatable {
        case added(Annotation)
        case removed(Annotation)
        case updated(before: Annotation, after: Annotation)
    }

    private var undoStack: [Change] = []
    private var redoStack: [Change] = []

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call after successfully performing `change` against the engine.
    /// Any prior redo history is discarded — the usual undo-stack contract
    /// (a new action after an undo invalidates what was undone).
    public mutating func record(_ change: Change) {
        undoStack.append(change)
        redoStack.removeAll()
    }

    /// Pops the most recent recorded change and returns the change to
    /// *perform* against the engine to undo it — e.g. undoing a `.added`
    /// returns `.removed` (the caller should call `remove`), not the
    /// original `.added`.
    public mutating func undo() -> Change? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        return Self.inverse(of: change)
    }

    /// Pops the most recently undone change and returns the change to
    /// *perform* to redo it — the original forward change, applied again.
    public mutating func redo() -> Change? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        return change
    }

    private static func inverse(of change: Change) -> Change {
        switch change {
        case .added(let annotation): .removed(annotation)
        case .removed(let annotation): .added(annotation)
        case .updated(let before, let after): .updated(before: after, after: before)
        }
    }
}
