import Foundation

/// A structural operation on a document's page list. One case per operation
/// rather than separate protocol methods, so `PageOrganizer` implementations
/// (and any undo stack built on top, per DocumentSession's ownership) have a
/// single, exhaustively-switchable operation log entry shape.
public enum PageOperation: Sendable, Codable, Equatable {
    case insert(from: DocumentHandle, sourcePage: PageIndex, at: PageIndex)
    case delete(PageIndex)
    case reorder(from: PageIndex, to: PageIndex)
    case rotate(PageIndex, by: PageRotation)
}

/// Engine-neutral page-list mutation (insert/delete/reorder/rotate).
/// Implementations perform the mutation against the document referenced by
/// `document` — `PageOperation.insert`'s `from` may reference a *different*
/// open document (page import) or the same one (duplicate).
public protocol PageOrganizer: Sendable {
    func apply(_ operation: PageOperation, to document: DocumentHandle) async throws
}
